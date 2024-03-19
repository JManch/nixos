{ lib
, pkgs
, outputs
, username
, hostname
, ...
}:
let
  inherit (lib) utils;

  deployScript = pkgs.writeShellApplication {
    name = "deploy-host";
    runtimeInputs = with pkgs; [
      age
      # nixos-anywhere does not allow passing extra flags to the nix build commands
      # so we have to patch it. The patch overrides our 'firstBoot' flake input to
      # 'true' so that we can change certain config options for the very first
      # build of a system. This is useful for options like secure boot that need
      # extra configuration to work.
      # This patch also preserves the file ownership in the rsync command used
      # for extra-files transfer. This is needed for deploying secrets to the
      # home directory.
      (pkgs.nixos-anywhere.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ../../../patches/nixosAnywhere.patch ];
      }))
      gnutar
    ];
    text = /*bash*/ ''
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: deploy-host <hostname> <ip_address>"
        exit 1
      fi

      hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
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
        echo "Error: Host '$hostname' does not exist" >&2
        exit 1
      fi

      secret_temp=$(mktemp -d)
      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$secret_temp"
        sudo rm -rf "$temp"
      }
      trap cleanup EXIT
      install -d -m755 "$temp/persist/etc/ssh"
      install -d -m755 "$temp/persist/home"
      install -d -m700 "$temp/persist/home/${username}"
      install -d -m700 "$temp/persist/home/${username}/.ssh"
      install -d -m755 "$temp/persist/home/${username}/.config"

      kit_path="${../../../hosts/ssh-bootstrap-kit}"
      age -d -o "$secret_temp/ssh-bootstrap-kit.tar" "$kit_path"
      tar -xf "$secret_temp/ssh-bootstrap-kit.tar" -C "$secret_temp"
      rm "$secret_temp/ssh-bootstrap-kit.tar"
      mv "$secret_temp/$hostname"/* "$temp/persist/etc/ssh"
      mv "$secret_temp/id_ed25519" "$temp/persist/home/${username}/.ssh"
      mv "$secret_temp/id_ed25519.pub" "$temp/persist/home/${username}/.ssh"
      mv "$secret_temp"/${username}/* "$temp/persist/home/${username}/.ssh"
      rm -rf "$secret_temp"

      cp -r /home/${username}/.config/nixos "$temp/persist/home/${username}/.config/nixos"

      sudo chown -R root:root "$temp/persist"
      sudo chown -R ${username}:users "$temp/persist/home"

      nixos-anywhere --extra-files "$temp" --flake "/home/${username}/.config/nixos#$hostname" "root@$ip_address"
      sudo rm -rf "$temp"
    '';
  };
in
{
  environment.systemPackages = [ deployScript ];

  programs.zsh = {
    enable = true;

    shellAliases = {
      rebuild-switch = "sudo nixos-rebuild switch --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-test = "sudo nixos-rebuild test --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-boot = "sudo nixos-rebuild boot --flake /home/${username}/.config/nixos#${hostname}";
      # cd here because I once had a bad experience where I accidentally built
      # in /nix/store and it irrepairably corrupted the store
      rebuild-build = "cd && nixos-rebuild build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-dry-build = "nixos-rebuild dry-build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-dry-activate = "sudo nixos-rebuild dry-activate --flake /home/${username}/.config/nixos#${hostname}";
      build-iso = "nix build /home/${username}/.config/nixos#nixosConfigurations.installer.config.system.build.isoImage";
    };
  };
}
