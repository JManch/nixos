{ lib
, pkgs
, self
, username
, ...
}:
let
  inherit (lib) utils concatStringsSep attrNames filterAttrs mapAttrsToList all hasAttr;

  deployScript = pkgs.writeShellApplication {
    name = "deploy-host";
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
    text = /*bash*/ ''
      if [ "$#" -ne 2 ]; then
        echo "Usage: deploy-host <hostname> <ip_address>"
        exit 1
      fi

      # Exclude hosts that use zfs disk encryption because nixos-anywhere will
      # get stuck when setting disk passphrase
      hosts=(${
        concatStringsSep " " (
          attrNames (
            filterAttrs (
              _: value:
              all (v: v == false) (
                mapAttrsToList (_: pool: hasAttr "encryption" pool.rootFsOptions) value.config.disko.devices.zpool
              )
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

      host_config="/home/${username}/.config/nixos#nixosConfigurations.$hostname.config"
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

      install -d -m755 "$temp/$rootDir/etc/ssh"
      install -d -m755 "$temp/$rootDir/home"
      install -d -m700 "$temp/$rootDir/home/$username"
      install -d -m700 "$temp/$rootDir/home/$username/.ssh"
      install -d -m755 "$temp/$rootDir/home/$username/.config"

      kit_path="${../../../hosts/ssh-bootstrap-kit}"
      age -d "$kit_path" | tar -xf - -C "$secret_temp"
      mv "$secret_temp/$hostname"/* "$temp/$rootDir/etc/ssh"

      if [ "$username" = "joshua" ]; then
        mv "$secret_temp/id_ed25519" "$temp/$rootDir/home/$username/.ssh"
        mv "$secret_temp/id_ed25519.pub" "$temp/$rootDir/home/$username/.ssh"
      fi

      if [ -d "$secret_temp/$username" ]; then
        mv "$secret_temp/$username"/* "$temp/$rootDir/home/$username/.ssh"
      fi
      rm -rf "$secret_temp"

      cp -r /home/${username}/.config/nixos "$temp/$rootDir/home/$username/.config/nixos"

      sudo chown -R root:root "$temp/$rootDir"
      # It's fine if the username here does not match the new hosts username as
      # the UID will match and that's all that matters
      sudo chown -R ${username}:users "$temp/$rootDir/home"

      nixos-anywhere --extra-files "$temp" --flake "/home/${username}/.config/nixos#$hostname" "root@$ip_address"
      sudo rm -rf "$temp"
    '';
  };
in
{
  environment.systemPackages = [ deployScript ];
}
