{
  lib,
  pkgs,
  selfPkgs,
  adminUsername,
}:
let
  inherit (lib) ns getExe;

  setupSdImage = pkgs.writeShellApplication {
    name = "setup-sd-image";
    runtimeInputs = [
      pkgs.parted
      selfPkgs.bootstrap-kit
    ];
    text = ''
      if [ "$(id -u)" != "0" ]; then
         echo "This script must be run as root" 1>&2
         exit 1
      fi

      if [ "$#" -ne 2 ]; then
        echo "Usage: setup-sd-image <hostname> <result_path>"
        exit 1
      fi
      ${lib.${ns}.exitTrapBuilder}

      hostname="$1"
      result="$2"

      flake="/home/${adminUsername}/.config/nixos"
      if [ ! -d $flake ]; then
        echo "Flake does not exist locally so using remote from github"
        flake="github:JManch/nixos"
      fi

      host_config="$flake#nixosConfigurations.$hostname.config"
      fs_type=$(nix eval --raw "$host_config.${ns}.hardware.file-system.type")
      username=$(nix eval --raw "$host_config.${ns}.core.users.username")

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

      echo "### Decrypting bootstrap-kit ###"
      bootstrap_kit=$(mktemp -d)
      clean_up_keys() {
        rm -rf "$bootstrap_kit"
      }
      add_exit_trap clean_up_keys
      bootstrap-kit decrypt "$bootstrap_kit"

      echo "### Installing keys ###"
      install -d -m755 "$rootDir/etc/ssh" "$rootDir/home"
      install -d -m700 "$rootDir/home/$username" "$rootDir/home/${adminUsername}"
      install -d -m700 "$rootDir/home/$username/.ssh" "$rootDir/home/${adminUsername}/.ssh"

      # Host keys
      mv "$bootstrap_kit/$hostname"/ssh_host_ed25519_key* "$rootDir/etc/ssh"

      # Nix store keys
      if [ -f "$bootstrap_kit/$hostname/nix_store_ed25519_key" ]; then
        mv "$bootstrap_kit/$hostname"/nix_store_ed25519_key* "$rootDir/etc/nix"
      fi

      # User keys
      if [ -d "$bootstrap_kit/$username" ]; then
        mv "$bootstrap_kit/$username"/* "$rootDir/home/$username/.ssh"
      fi

      # Admin user keys
      if [[ -d "$bootstrap_kit/${adminUsername}" && -n "$(ls -A "$bootstrap_kit/${adminUsername}")" ]]; then
        mv "$bootstrap_kit/${adminUsername}"/* "$rootDir/home/${adminUsername}/.ssh"
      fi

      rm -rf "$bootstrap_kit"
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

  buildInstaller = pkgs.writeShellApplication {
    name = "build-installer";
    runtimeInputs = [ pkgs.nix ];
    text = ''
      if [ -z "$1" ]; then
        echo "Usage: build-installer <name>"
        exit 1
      fi
      installer=$1

      flake="/home/${adminUsername}/.config/nixos"
      if [ ! -d $flake ]; then
        echo "Flake does not exist locally so using remote from github"
        flake="github:JManch/nixos"
      fi

      # shellcheck disable=SC2016
      installer_exists=$(nix eval --impure --expr 'with import <nixpkgs> {}; pkgs.lib.hasAttr "installer-'"$installer"'" (builtins.getFlake "'"$flake"'").packages.''${pkgs.system}')
      if [[ $installer_exists = "false" ]]; then
        echo "Error: Installer '$installer' does not exist" >&2
        exit 1
      fi

      # If the installer name matches a hostname it means it's a custom
      # installer with a custom implementation
      # shellcheck disable=SC2016
      host_exists=$(nix eval --impure --expr 'with import <nixpkgs> {}; pkgs.lib.hasAttr "'"$installer"'" (builtins.getFlake "'"$flake"'").nixosConfigurations')
      if [[ $host_exists = "true" ]]; then
        host_config="$flake#nixosConfigurations.$installer.config"
        fs_type=$(nix eval --raw "$host_config.${ns}.hardware.file-system.type")
        result=$(nix build "$flake#installer-$1" --print-out-paths)
        if [ "$fs_type" = "sd-image" ]; then
          sudo ${getExe setupSdImage} "$1" "$result"
        fi
      else
        nix build "$flake#installer-$1" --print-out-paths
      fi
    '';
  };

in
{
  enableOpt = false;

  ns.adminPackages = [
    setupSdImage
    buildInstaller
  ];
}
