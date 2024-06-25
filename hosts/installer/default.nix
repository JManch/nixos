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

      vmInstall=false
      read -p "Are you installing this host in a virtual machine? (y/N): " -n 1 -r
      echo
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        vmInstall=true
        echo "WARNING: The vmInstall flake input will only be overridden for the initial install"
        echo "Any nixos-rebuild commands ran in the VM will need '--override-input vmInstall github:JManch/$vmInstall' manually added"
        # Disko does not allow overriding inputs so instead we update the flake
        # lock file of our downloaded config
        nix flake lock \
          --update-input vmInstall \
          --override-input vmInstall "github:JManch/true" \
          "$config"
      fi

      echo "WARNING: All data on the drive specified in the disko config of host '$hostname' will be destroyed"
      read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi

      temp_keys=$(mktemp -d)
      ssh_dir="/root/.ssh"
      cleanup() {
        rm -rf "$ssh_dir"
        rm -rf "$temp_keys"
      }
      trap cleanup EXIT

      echo "Decrypting ssh-bootstrap-kit..."
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

      host_config="$config#nixosConfigurations.$hostname.config"
      impermanence=$(nix eval "$host_config.modules.system.impermanence.enable")
      rootDir="/mnt"
      if [ "$impermanence" = "true" ]; then
        rootDir="/mnt/persist"
      fi

      username=$(nix eval --raw "$host_config.modules.core.username")
      mkdir -p "$rootDir"/{etc/ssh,"home/$username/.ssh"}

      # Install host keys
      mv "$temp_keys/$hostname"/* "$rootDir/etc/ssh"

      # Install user keys
      if [ -d "$temp_keys/$username" ]; then
        mv "$temp_keys/$username"/* "$rootDir/home/$username/.ssh"
      fi

      # Install user nix-resources key
      mv "$temp_keys"/id_nix-resources* "$rootDir/home/$username/.ssh"

      rm -rf "$temp_keys"
      chown -R nixos:users "$rootDir/home/$username"

      # WARN: nixos-install has a bunch of options that are not documented in
      # the man page. The source is here: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/tools/nixos-install.sh

      # We have to clear the nix cache because previously cached paths refer to
      # /nix/store whilst nixos-install expects store paths at /mnt/nix/store.
      # Not sure why this isn't handled in the nixos-install script...
      rm -rf /root/.cache/nix

      # By default, nixos-install creates a tmpdir at `/mnt/$(mktmp -d)`. This
      # is a problem on impermanence hosts as / is not a mounted filesystem so
      # the build will likely fail as it runs out of space. We workaround this
      # by creating the tmpdir ourselves.
      tmpdir="$(mktemp -d -p "$rootDir")"
      trap 'rm -rf $tmpdir' EXIT
      TMPDIR="$tmpdir" nixos-install \
        --no-root-passwd \
        --no-write-lock-file \
        --no-channel-copy \
        --override-input firstBoot "github:JManch/true" \
        --override-input vmInstall "github:JManch/$vmInstall" \
        --flake "$config#$hostname"
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
    zellij
    btop
  ]) ++ [ installScript ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  zramSwap.enable = true;

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
