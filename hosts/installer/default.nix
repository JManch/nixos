{ lib, pkgs, inputs, outputs, username, ... }:
let
  inherit (lib) utils;
  installScript = pkgs.writeShellApplication {
    name = "install-host";
    runtimeInputs = with pkgs; [
      age
      disko
      gitMinimal
    ];
    text = /*bash*/ ''

      if [ "$(id -u)" != "0" ]; then
         echo "This script must be run as root" 1>&2
         exit 1
      fi

      if [ -z "$1" ]; then
        echo "Usage: install-host <hostname>"
        exit 1
      fi
      hostname=$1
      hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts outputs))})
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

      echo "WARNING: All data on the drive specified in the disko config of host '$hostname' will be destroyed"
      read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi;

      config="/root/nixos"
      if [ ! -d "$config" ]; then
        git clone https://github.com/JManch/nixos "$config"
      fi

      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$temp"
      }
      trap cleanup EXIT

      age -d -o "$temp/ssh-bootstrap-kit.tar" "$config/hosts/ssh-bootstrap-kit"
      tar -xf "$temp/ssh-bootstrap-kit.tar" -C "$temp"
      rm -f "$temp/ssh-bootstrap-kit.tar";

      ssh_dir="/root/.ssh"
      rm -rf "$ssh_dir"
      mkdir -p "$ssh_dir"
      mv "$temp/$hostname/ssh_host_ed25519_key" "$ssh_dir/id_ed25519"
      mv "$temp/$hostname/ssh_host_ed25519_key.pub" "$ssh_dir/id_ed25519.pub"
      mv "$temp/${username}" "$ssh_dir"
      rm -rf "$temp"

      echo "Starting disko format and mount..."
      disko --mode disko --flake "$config#$hostname"
      echo "Disko finished"

      mkdir -p /mnt/persist/{etc/ssh,home/${username}/.ssh}
      cp "$ssh_dir/id_ed25519" /mnt/persist/etc/ssh/ssh_host_ed25519_key
      cp "$ssh_dir/id_ed25519.pub" /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
      mv "$ssh_dir"/${username}/* /mnt/persist/home/${username}/.ssh/
      chown -R nixos:users /mnt/persist/home/${username}

      nixos-install --no-root-passwd --flake "$config#$hostname"
      rm -rf "$ssh_dir"

    '';
  };
in
{
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  environment.systemPackages = with pkgs; [
    # nixos-anywhere needs rsync for transfering secrets
    rsync
    gitMinimal
    neovim
    installScript
  ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    knownHosts = {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };
}
