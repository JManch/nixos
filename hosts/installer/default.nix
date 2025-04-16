# Connecting to wifi:
# List wireless interfaces with `iwconfig`
# Generate a wpa supplicant config with `wpa_passphrase SSID | sudo tee /etc/wpa_supplicant.conf`
# Run `sudo wpa_supplicant -c /etc/wpa_supplicant.conf -i <interface>` (-B to run in background)
{
  lib,
  pkgs,
  self,
  base,
  modulesPath,
  ...
}:
let
  inherit (lib) ns;
  installScript = pkgs.writeShellApplication {
    name = "install-host";

    runtimeInputs = with pkgs; [
      self.packages.${pkgs.system}.bootstrap-kit
      disko
      gitMinimal
      # The upstream package hardcodes the database path but we want to be able
      # to modify it at runtime using the --export and --database-path flags
      (sbctl.overrideAttrs {
        ldflags = [
          "-s"
          "-w"
        ];
      })
    ];

    text = ''
      if [ "$(id -u)" != "0" ]; then
         echo "This script must be run as root" 1>&2
         exit 1
      fi

      if [ "$#" -ne 1 ]; then
        echo "Usage: install-host <hostname>"
        exit 1
      fi
      ${lib.${ns}.exitTrapBuilder}

      hostname=$1

      flake="/root/nixos"
      if [ ! -d "$flake" ]; then
        read -p "Use the flake this ISO was built with? (default is to fetch latest from GitHub) (y/N): " -n 1 -r
        echo
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
          cp -r --no-preserve=mode "${self}" "$flake"
        else
          git clone https://github.com/JManch/nixos "$flake"
        fi
      fi

      bootstrap_kit=$(mktemp -d)
      ssh_dir="/root/.ssh"
      clean_up_keys() {
        rm -rf "$bootstrap_kit"
        rm -rf "$ssh_dir"
      }
      add_exit_trap clean_up_keys

      echo "### Decrypting bootstrap-kit ###"
      bootstrap-kit decrypt "$bootstrap_kit"

      rm -rf "$ssh_dir"
      mkdir -p "$ssh_dir"
      cp "$bootstrap_kit/joshua/id_ed25519" "$ssh_dir"
      cp "$bootstrap_kit/joshua/id_ed25519.pub" "$ssh_dir"

      vmInstall=false
      read -p "Are you installing this host in a virtual machine? (y/N): " -n 1 -r
      echo
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        vmInstall=true
        echo "WARNING: The vmInstall flake input will only be overridden for the initial install"
        echo "Any nixos-rebuild commands ran in the VM will need '--override-input vmInstall github:JManch/$vmInstall' manually added"
        # Disko does not allow overriding inputs so instead we update the flake
        # lock file of our downloaded config
        nix flake update \
          vmInstall \
          --override-input vmInstall "github:JManch/true" \
          --flake "$flake"
      fi

      echo "### Fetching host information ###"
      host_config="$flake#nixosConfigurations.$hostname.config"
      username=$(nix eval --raw "$host_config.${ns}.core.users.username")
      admin_username=$(nix eval --raw "$host_config.${ns}.core.users.adminUsername")
      impermanence=$(nix eval "$host_config.${ns}.system.impermanence.enable")
      secure_boot=$(nix eval "$host_config.${ns}.hardware.secure-boot.enable")
      has_disko=$(nix eval --impure --expr "(builtins.getFlake \"$flake\").nixosConfigurations.$hostname.config.disko.devices.disk or {} != {}")

      if [[ "$has_disko" = "false" ]]; then
          echo "The host does not have a disko config"
          echo "You'll need to manually formatted and partitioned the disk then mounted it to /mnt";
          read -p "Have you done this? (y/N): " -n 1 -r
          echo
          if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "Aborting" >&2
            exit 1
          fi
      fi

      if [ "$impermanence" = "true" ]; then
        rootDir="/mnt/persist"
      else
        rootDir="/mnt"
      fi

      read -p "Enter the address of a remote build host (leave empty to build locally): " -r build_host
      if [ -z "$build_host" ]; then
        build_host=""
      else
        if ! nix store ping --store "ssh://$build_host" &> /dev/null; then
          echo "Error: build host $build_host cannot be pinged, aborting" >&2
          exit 1
        fi
      fi

      if [ "$has_disko" = "true" ]; then
        echo "WARNING: All data on the drive specified in the disko config of host '$hostname' will be destroyed"
        read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
        echo
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting" >&2
          exit 1
        fi
      fi

      install_keys() {
        echo "### Installing keys ###"
        install -d -m755 "$rootDir/etc/ssh" "$rootDir/home"
        install -d -m700 "$rootDir/home/$username" "$rootDir/home/$admin_username"
        install -d -m700 "$rootDir/home/$username/.ssh" "$rootDir/home/$admin_username/.ssh"

        # Host keys
        mv "$bootstrap_kit/$hostname"/* "$rootDir/etc/ssh"

        # User keys
        if [ -d "$bootstrap_kit/$username" ]; then
          mv "$bootstrap_kit/$username"/* "$rootDir/home/$username/.ssh"
        fi

        # Admin user keys
        if [[ -d "$bootstrap_kit/$admin_username" && -n "$(ls -A "$bootstrap_kit/$admin_username")" ]]; then
          mv "$bootstrap_kit/$admin_username"/* "$rootDir/home/$admin_username/.ssh"
        fi

        rm -rf "$bootstrap_kit"
        # user:users
        chown -R 1000:100 "$rootDir/home/$username"

        if [ "$username" != "$admin_username" ]; then
          # admin_user:wheel
          chown -R 1:1 "$rootDir/home/$admin_username"
        fi

        if [ "$secure_boot" = "true" ]; then
          sbctl create-keys --export "$rootDir/etc/secureboot/keys/" --database-path "$rootDir/etc/secureboot/"
        fi
      }

      run_disko() {
        if [ "$has_disko" = "true" ]; then
          echo "### Running disko format and mount ###"
          disko --mode disko --flake "$flake#$hostname"
        fi
      }

      install_nixos() {
        if [ -n "$build_host" ]; then
          echo "### Generating system derivation ###"
          drv=$(nix eval \
            --raw \
            --override-input firstBoot "github:JManch/true" \
            --override-input vmInstall "github:JManch/$vmInstall" \
            "$host_config.system.build.toplevel.drvPath")

          ssh_ctrl=$(mktemp -d)
          clean_up_ssh_ctrl() {
            for ctrl in "$ssh_ctrl"/ssh-*; do
              ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
            done
            rm -rf "$ssh_ctrl"
          }
          add_exit_trap clean_up_ssh_ctrl
          ssh_opts="-o ControlMaster=auto -o ControlPath=$ssh_ctrl/ssh-%n -o ControlPersist=60"

          echo "### Copying system derivation to remote host ###"
          NIX_SSHOPTS="$ssh_opts" nix copy \
            --to "ssh://$build_host" \
            --derivation "$drv"

          echo "### Realising system derivation on remote host ###"
          ssh_opts="-o ControlMaster=auto -o ControlPath=$ssh_ctrl/ssh-%n -o ControlPersist=60"
          nixos_system=$(eval ssh "$ssh_opts" "$build_host" nix-store --realise "$drv")

          echo "### Copying system closure from remote host ###"
          NIX_SSHOPTS="$ssh_opts" nix copy \
            --from "ssh://$build_host" \
            --to "/mnt" \
            --no-check-sigs \
            "$nixos_system"
        else
          echo "### Building system ###"
          # nix build uses a tmpdir for build files. We need to make sure
          # this is located in persistent storage on the mounted filesystem.
          nix_build_tmp="$(mktemp -d -p "$rootDir")"
          # shellcheck disable=SC2016
          add_exit_trap 'rm -rf $nix_build_tmp'
          nixos_system=$(
            TMPDIR="$nix_build_tmp" nix build \
              --store "/mnt" \
              --no-link \
              --print-out-paths \
              --extra-experimental-features "nix-command flakes" \
              --override-input firstBoot "github:JManch/true" \
              --override-input vmInstall "github:JManch/$vmInstall" \
              "$flake#nixosConfigurations.\"$hostname\".config.system.build.toplevel"
          )
        fi

        echo "### Installing system ###"
        nixos-install \
          --root "/mnt" \
          --no-root-passwd \
          --no-channel-copy \
          --system "$nixos_system"
      }
      run_disko
      install_keys
      install_nixos
    '';
  };
in
{
  imports = [ "${modulesPath}/installer/${base}" ];

  config = {
    isoImage.compressImage = false;

    environment.systemPackages =
      (with pkgs; [
        gitMinimal
        zellij
        btop
        neovim
      ])
      ++ [ installScript ];

    nix.settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      # Causes a lot of spam in the install script otherwise
      warn-dirty = false;
    };

    zramSwap.enable = true;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;

      knownHosts =
        (lib.mapAttrs (host: _: {
          publicKeyFile = ../${host}/ssh_host_ed25519_key.pub;
          extraHostNames = [ "${host}.lan" ];
        }) self.nixosConfigurations)
        // {
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
    };

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"
    ];

    system.stateVersion = "24.05";
  };
}
