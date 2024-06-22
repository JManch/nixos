{ lib
, pkgs
, self
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

      host_config="$config#nixosConfigurations.$hostname.config"
      username=$(nix eval --raw "$host_config.usrEnv.username")
      impermanence=$(nix eval "$host_config.modules.system.impermanence.enable")

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

      # Temporarily copy host keys to id_ed25519 as they are used for remote
      # private repo access
      mv "$temp/$hostname/ssh_host_ed25519_key" "$ssh_dir/id_ed25519"
      mv "$temp/$hostname/ssh_host_ed25519_key.pub" "$ssh_dir/id_ed25519.pub"

      # Get user keys for home-manager secret decryption
      if [ -d "$temp/$username" ]; then
        mv "$temp/$username" "$ssh_dir"
      fi

      # Get personal ssh key. Only needed for my hosts.
      if [ "$username" = "joshua" ]; then
        mv "$temp/id_ed25519" "$ssh_dir/id_ed25519.ignore"
        mv "$temp/id_ed25519.pub" "$ssh_dir/id_ed25519.pub.ignore"
      fi
      rm -rf "$temp"

      echo "Starting disko format and mount..."
      disko --mode disko --flake "$config#$hostname"
      echo "Disko finished"

      rootDir="/mnt"
      if [ "$impermanence" = "true" ]; then
        rootDir="/mnt/persist"
      fi

      mkdir -p "$rootDir"/{etc/ssh,"home/$username/.ssh","home/$username/.config"}

      cp "$ssh_dir/id_ed25519" "$rootDir/etc/ssh/ssh_host_ed25519_key"
      cp "$ssh_dir/id_ed25519.pub" "$rootDir/etc/ssh/ssh_host_ed25519_key.pub"

      if [ -d "$ssh_dir/$username" ]; then
        mv "$ssh_dir/$username"/* "$rootDir/home/$username/.ssh"
      fi

      if [ "$username" = "joshua" ]; then
        mv "$ssh_dir/id_ed25519.ignore" "$rootDir/home/$username/.ssh/id_ed25519"
        mv "$ssh_dir/id_ed25519.pub.ignore" "$rootDir/home/$username/.ssh/id_ed25519.pub"
      fi

      rm -rf "$rootDir/home/$username/.config/nixos"
      cp -r "$config" "$rootDir/home/$username/.config/nixos"
      chown -R nixos:users "$rootDir/home/$username"

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
