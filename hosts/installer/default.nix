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

      echo "WARNING: All data on the drive specified in the disko config of host '$hostname' will be destroyed"
      read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi;

      temp_keys=$(mktemp -d)
      ssh_dir="/root/.ssh"
      cleanup() {
        rm -rf "$ssh_dir"
        rm -rf "$temp_keys"
      }
      trap cleanup EXIT

      age -d "$config/hosts/ssh-bootstrap-kit" | tar -xf - -C "$temp_keys"

      rm -rf "$ssh_dir"
      mkdir -p "$ssh_dir"

      # Temporarily copy nix-resources keys to id_ed25519 as they are used for
      # accessing the private repo
      cp "$temp_keys/id_nix-resources" "$ssh_dir/id_ed25519"
      cp "$temp_keys/id_nix-resources.pub" "$ssh_dir/id_ed25519.pub"

      echo "Starting disko format and mount..."
      disko --mode disko --flake "$config#$hostname"
      echo "Disko finished"

      impermanence=$(nix eval "$host_config.modules.system.impermanence.enable")
      rootDir="/mnt"
      if [ "$impermanence" = "true" ]; then
        rootDir="/mnt/persist"
      fi

      username=$(nix eval --raw "$host_config.modules.core.username")
      mkdir -p "$rootDir"/{etc/ssh,"home/$username/.ssh","home/$username/.config"}

      # Install host keys
      mv "$temp_keys/$hostname"/* "$rootDir/etc/ssh"

      # Install user keys
      if [ -d "$temp_keys/$username" ]; then
        mv "$temp_keys/$username"/* "$rootDir/home/$username/.ssh"
      fi

      # Install user nix-resources key
      mv "$temp_keys"/id_nix-resources* "$rootDir/home/$username/.ssh"

      rm -rf "$temp_keys"
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
