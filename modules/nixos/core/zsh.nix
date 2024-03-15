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
      nixos-anywhere
      gnutar
    ];
    text = /*bash*/ ''
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: deploy-host <hostname> <ip_address> <extra_args>"
        exit 1
      fi

      hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
      hostname=$1
      ip_address=$2
      extra_args=''${3:-}

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

      kit_path="/home/${username}/files/secrets/ssh-bootstrap-kit"
      if [[ ! -e "$kit_path" ]]; then
        echo "Error: SSH bootstrap kit is not in the expected path '$kit_path'" >&2
        exit 1
      fi

      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$temp"
      }
      trap cleanup EXIT
      install -d -m755 "$temp/persist/etc/ssh"

      age -d -o "$temp/ssh-bootstrap-kit.tar" "$kit_path"
      tar -xf "$temp/ssh-bootstrap-kit.tar" --strip-components=1 -C "$temp/persist/etc/ssh" "$hostname"
      rm "$temp/ssh-bootstrap-kit.tar"

      nixos-anywhere --extra-files "$temp" "$extra_args" --flake "/home/${username}/.config/nixos#$hostname" "root@$ip_address"
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
