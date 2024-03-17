{ lib, pkgs, outputs, nixpkgs, username, ... }:
let
  inherit (lib) utils;
  installScript = pkgs.writeShellApplication {
    name = "install-host";
    runtimeInputs = with pkgs; [
      disko
      gitMinimal
    ];
    text = /*bash*/ ''
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

      config="/home/nixos/nixos"
      rm -rf "$config"
      git clone https://github.com/JManch/nixos "$config"

      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$temp"
      }
      trap cleanup EXIT

      age -d -o "$temp/ssh-bootstrap-kit.tar" "$config/hosts/ssh-bootstrap-kit"
      tar -xf "$temp/ssh-bootstrap-kit.tar" -C "$temp"
      rm -f "$temp/ssh-bootstrap-kit.tar";

      mkdir -p /home/root/.ssh
      mv "$temp/$hostname/ssh_host_ed25519_key" /home/root/.ssh/id_ed25519
      mv "$temp/$hostname/ssh_host_ed25519_key.pub" /home/root/.ssh/id_ed25519.pub
      mv "$temp/${username}" /home/root/.ssh
      rm -rf "$temp"

      sudo disko --mode disko --flake "/home/nixos/nixos#$hostname"

      mkdir -p /mnt/persist/{etc/ssh,home/${username}/.ssh}
      cp /home/nixos/.ssh/id_ed25519 /mnt/persist/etc/ssh/ssh_host_ed25519_key
      cp /home/nixos/.ssh/id_ed25519.pub /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
      mv /home/nixos/.ssh/${username}/* /mnt/persist/home/${username}/.ssh/

      sudo nixos-install --no-root-passwd --flake /home/nixos/nixos#$hostname
      rm -rf /home/root/.ssh
    '';
  };
in
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  environment.systemPackages = with pkgs; [
    # nixos-anywhere needs rsync for transfering secrets
    rsync
    gitMinimal
    nvim
    installScript
  ];

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];
  };
}
