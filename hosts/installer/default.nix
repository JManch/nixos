{ lib
, pkgs
, self
, username
, modulesPath
, ...
}:
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

      if [ "$#" -ne 1 ]; then
        echo "Usage: install-host <hostname>"
        exit 1
      fi
      hostname=$1
      hosts=(${lib.concatStringsSep " " (builtins.attrNames (utils.hosts self))})
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

      config="/root/nixos"
      if [ ! -d "$config" ]; then
        git clone https://github.com/JManch/nixos "$config"
      fi

      echo "WARNING: All data on the drive specified in the disko config of host '$hostname' will be destroyed"
      read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi;

      temp=$(mktemp -d)
      cleanup() {
        rm -rf "$temp"
      }
      trap cleanup EXIT

      age -d "$config/hosts/ssh-bootstrap-kit" | tar -xf - -C "$temp"

      ssh_dir="/root/.ssh"
      rm -rf "$ssh_dir"
      mkdir -p "$ssh_dir"
      mv "$temp/$hostname/ssh_host_ed25519_key" "$ssh_dir/id_ed25519"
      mv "$temp/$hostname/ssh_host_ed25519_key.pub" "$ssh_dir/id_ed25519.pub"
      mv "$temp/${username}" "$ssh_dir"
      mv "$temp/id_ed25519" "$ssh_dir/id_ed25519.ignore"
      mv "$temp/id_ed25519.pub" "$ssh_dir/id_ed25519.pub.ignore"
      rm -rf "$temp"

      echo "Starting disko format and mount..."
      disko --mode disko --flake "$config#$hostname"
      echo "Disko finished"

      mkdir -p /mnt/persist/{etc/ssh,home/${username}/.ssh,home/${username}/.config}
      cp "$ssh_dir/id_ed25519" /mnt/persist/etc/ssh/ssh_host_ed25519_key
      cp "$ssh_dir/id_ed25519.pub" /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
      mv "$ssh_dir"/${username}/* /mnt/persist/home/${username}/.ssh
      mv "$ssh_dir/id_ed25519.ignore" /mnt/persist/home/${username}/.ssh/id_ed25519
      mv "$ssh_dir/id_ed25519.pub.ignore" /mnt/persist/home/${username}/.ssh/id_ed25519.pub
      rm -rf /mnt/persist/home/${username}/.config/nixos
      cp -r "$config" /mnt/persist/home/${username}/.config/nixos
      chown -R nixos:users /mnt/persist/home/${username}

      nixos_system=$(
        nix build \
          --print-out-paths \
          --no-link \
          --extra-experimental-features "nix-command flakes" \
          --no-write-lock-file \
          --override-input firstBoot "github:JManch/true" \
          "$config#nixosConfigurations.\"$hostname\".config.system.build.toplevel"
      )

      nixos-install --no-root-passwd --no-channel-copy --system "$nixos_system"
      rm -rf "$ssh_dir"

    '';
  };
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  environment.systemPackages = (with pkgs; [
    # nixos-anywhere needs rsync for transfering secrets
    rsync
    gitMinimal
    neovim
  ]) ++ [ installScript ];

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
