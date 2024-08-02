{
  lib,
  pkgs,
  self,
  adminUsername,
  ...
}:
let
  inherit (lib)
    utils
    concatStringsSep
    attrNames
    filterAttrs
    ;

  remoteInstallScript = pkgs.writeShellApplication {
    name = "install-remote";
    runtimeInputs = [
      pkgs.age
      # Nixos-anywhere does not allow passing extra flags to the nix build commands
      # so we have to patch it. The patch overrides our 'firstBoot' flake input to
      # 'true' so that we can change certain config options for the very first
      # build of a system. This is useful for options like secure boot that need
      # extra configuration to work.

      # The patch also preserves original file ownership of files transfered
      # with --extra-files. This is needed for deploying secrets to the home
      # directory with correct permissions.
      (utils.addPatches pkgs.nixos-anywhere [ ../../../patches/nixosAnywhere.patch ])
      pkgs.gnutar
    ];
    text = # bash
      ''
        if [ "$#" -ne 2 ]; then
          echo "Usage: install-remote <hostname> <ip_address>"
          exit 1
        fi

        # Exclude hosts that use zfs disk encryption because nixos-anywhere will
        # get stuck when setting disk passphrase
        hosts=(${
          concatStringsSep " " (
            attrNames (
              filterAttrs (
                _: value: !(with value.config.modules.hardware.fileSystem; type == "zfs" && zfs.encryption.enable)
              ) (utils.hosts self)
            )
          )
        })

        hostname=$1
        ip_address=$2

        match=0
        for host in "''${hosts[@]}"; do
          if [[ $host = "$hostname" ]]; then
            match=1
            break
          fi
        done
        if [[ $match = 0 ]]; then
          echo "Error: Host '$hostname' either does not exist or uses disk encryption" >&2
          exit 1
        fi

        flake="/home/${adminUsername}/.config/nixos"
        if [ ! -d $flake ]; then
          echo "Flake does not exist locally so using remote from github"
          flake="github:JManch/nixos"
        fi

        host_config="$flake#nixosConfigurations.$hostname.config"
        username=$(nix eval --raw "$host_config.modules.core.username")
        impermanence=$(nix eval "$host_config.modules.system.impermanence.enable")

        secret_temp=$(mktemp -d)
        temp=$(mktemp -d)
        cleanup() {
          rm -rf "$secret_temp"
          sudo rm -rf "$temp"
        }
        trap cleanup EXIT

        rootDir=""
        if [ "$impermanence" = "true" ]; then
          rootDir="persist"
        fi

        install -d -m755 "$temp/$rootDir/etc/ssh" "$temp/$rootDir/home"
        install -d -m700 "$temp/$rootDir/home/$username" "$temp/$rootDir/home/${adminUsername}"
        install -d -m700 "$temp/$rootDir/home/$username/.ssh" "$temp/$rootDir/home/${adminUsername}/.ssh"

        kit_path="${../../../hosts/ssh-bootstrap-kit}"
        age -d "$kit_path" | tar -xf - -C "$secret_temp"

        # Install host keys
        mv "$secret_temp/$hostname"/* "$temp/$rootDir/etc/ssh"

        # Install user keys
        if [ -d "$secret_temp/$username" ]; then
          mv "$secret_temp/$username"/* "$temp/$rootDir/home/$username/.ssh"
        fi

        # Install admin user keys
        if [ -d "$secret_temp/${adminUsername}" ]; then
          mv "$secret_temp/${adminUsername}"/* "$temp/$rootDir/home/${adminUsername}/.ssh"
        fi

        rm -rf "$secret_temp"

        sudo chown -R root:root "$temp/$rootDir"

        # user:users
        sudo chown -R 1000:100 "$temp/$rootDir/home/$username"

        if [ "$username" != "${adminUsername}" ]; then
          # admin_user:wheel
          sudo chown -R 1:1 "$temp/$rootDir/home/${adminUsername}"
        fi

        nixos-anywhere --extra-files "$temp" --flake "$flake#$hostname" "root@$ip_address"
        sudo rm -rf "$temp"
      '';
  };
in
{
  adminPackages = [ remoteInstallScript ];
}
