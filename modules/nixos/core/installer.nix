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
    getExe
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
              ) self.nixosConfigurations
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

        temp_keys=$(mktemp -d)
        temp=$(mktemp -d)
        clean_up() {
          rm -rf "$temp_keys"
          sudo rm -rf "$temp"
        }
        trap clean_up EXIT
        kit_path="${../../../hosts/ssh-bootstrap-kit}"
        age -d "$kit_path" | tar -xf - -C "$temp_keys"

        rootDir="$temp"
        if [ "$impermanence" = "true" ]; then
          rootDir+="/persist"
        fi

        install -d -m755 "$rootDir/etc/ssh" "$rootDir/home"
        install -d -m700 "$rootDir/home/$username" "$rootDir/home/${adminUsername}"
        install -d -m700 "$rootDir/home/$username/.ssh" "$rootDir/home/${adminUsername}/.ssh"

        # Host keys
        mv "$temp_keys/$hostname"/* "$rootDir/etc/ssh"

        # User keys
        if [ -d "$temp_keys/$username" ]; then
          mv "$temp_keys/$username"/* "$rootDir/home/$username/.ssh"
        fi

        # Admin user keys
        if [[ -d "$temp_keys/${adminUsername}" && -n "$(ls -A "$temp_keys/${adminUsername}")" ]]; then
          mv "$temp_keys/${adminUsername}"/* "$rootDir/home/${adminUsername}/.ssh"
        fi

        rm -rf "$temp_keys"
        sudo chown -R root:root "$rootDir"

        # user:users
        sudo chown -R 1000:100 "$rootDir/home/$username"

        if [ "$username" != "${adminUsername}" ]; then
          # admin_user:wheel
          sudo chown -R 1:1 "$rootDir/home/${adminUsername}"
        fi

        nixos-anywhere --extra-files "$temp" --flake "$flake#$hostname" "root@$ip_address"
        sudo rm -rf "$temp"
      '';
  };

  setupSdImage = pkgs.writeShellApplication {
    name = "setup-sd-image";
    runtimeInputs = with pkgs; [
      parted
      age
    ];
    text = # bash
      ''
        if [ "$(id -u)" != "0" ]; then
           echo "This script must be run as root" 1>&2
           exit 1
        fi

        if [ "$#" -ne 2 ]; then
          echo "Usage: setup-sd-image <hostname> <result_path>"
          exit 1
        fi
        ${utils.exitTrapBuilder}

        hostname="$1"
        result="$2"

        flake="/home/${adminUsername}/.config/nixos"
        if [ ! -d $flake ]; then
          echo "Flake does not exist locally so using remote from github"
          flake="github:JManch/nixos"
        fi

        host_config="$flake#nixosConfigurations.$hostname.config"
        fs_type=$(nix eval --raw "$host_config.modules.hardware.fileSystem.type")
        username=$(nix eval --raw "$host_config.modules.core.username")

        if [ "$fs_type" != "sd-image" ]; then
          echo "Host $hostname does not have a sd image filesystem" 1>&2
          exit 1
        fi

        tmpdir=$(mktemp -d)
        clean_up() {
          umount /mnt/nixos-sd-image >/dev/null 2>&1 || true
          rm -rf "$tmpdir"
        }
        add_exit_trap clean_up

        if ! ls "$result"/sd-image/*.img >/dev/null 2>&1; then
          echo "Result path does not contain an sd image" 1>&2
          exit 1
        fi

        echo "### Mounting sd image ###"
        cp "$result"/sd-image/*.img "$tmpdir"
        start_sector=$(parted -s "$tmpdir"/*.img unit s print 2>/dev/null | grep ext4 | awk '{print $2}' | sed 's/s//')
        offset=$((start_sector * 512))

        rootDir="/mnt/nixos-sd-image"
        mkdir -p $rootDir
        mount -o loop,offset="$offset" -t ext4 "$tmpdir"/*.img "$rootDir"

        echo "### Decrypting ssh-bootstrap-kit ###"
        temp_keys=$(mktemp -d)
        clean_up_keys() {
          rm -rf "$temp_keys"
        }
        add_exit_trap clean_up_keys
        kit_path="${../../../hosts/ssh-bootstrap-kit}"
        age -d "$kit_path" | tar -xf - -C "$temp_keys"

        echo "### Installing keys ###"
        install -d -m755 "$rootDir/etc/ssh" "$rootDir/home"
        install -d -m700 "$rootDir/home/$username" "$rootDir/home/${adminUsername}"
        install -d -m700 "$rootDir/home/$username/.ssh" "$rootDir/home/${adminUsername}/.ssh"

        # Host keys
        mv "$temp_keys/$hostname"/* "$rootDir/etc/ssh"

        # User keys
        if [ -d "$temp_keys/$username" ]; then
          mv "$temp_keys/$username"/* "$rootDir/home/$username/.ssh"
        fi

        # Admin user keys
        if [[ -d "$temp_keys/${adminUsername}" && -n "$(ls -A "$temp_keys/${adminUsername}")" ]]; then
          mv "$temp_keys/${adminUsername}"/* "$rootDir/home/${adminUsername}/.ssh"
        fi

        rm -rf "$temp_keys"
        # user:users
        chown -R 1000:100 "$rootDir/home/$username"

        if [ "$username" != "${adminUsername}" ]; then
          # admin_user:wheel
          chown -R 1:1 "$rootDir/home/${adminUsername}"
        fi

        umount "$rootDir"
        mv "$tmpdir"/*.img .
      '';
  };

in
{
  adminPackages = [
    remoteInstallScript
    setupSdImage
  ];

  programs.zsh.interactiveShellInit = # bash
    ''
      build-installer() {
        if [ -z "$1" ]; then
          echo "Usage: build-installer <name>"
          return 1
        fi

        flake="/home/${adminUsername}/.config/nixos"
        if [ ! -d $flake ]; then
          echo "Flake does not exist locally so using remote from github"
          flake="github:JManch/nixos"
        fi

        host_config="$flake#nixosConfigurations.$1.config"
        fs_type=$(nix eval --raw "$host_config.modules.hardware.fileSystem.type")
        result=$(nix build "$flake#installer-$1" --print-out-paths)
        if [ "$fs_type" = "sd-image" ]; then
          sudo ${getExe setupSdImage} "$1" "$result"
        fi
      }
    '';
}
