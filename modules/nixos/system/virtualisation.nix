{ lib
, pkgs
, config
, inputs
, username
, ...
}:
let
  inherit (lib) mkIf mkMerge mkVMOverride mod;
  inherit (config.home-manager.users.${username}.modules.desktop) terminal;
  inherit (config.device) monitors cpu memory;
  inherit (config.modules.core) homeManager;
  cfg = config.modules.system.virtualisation;

  runVMScript = pkgs.writeShellApplication {
    name = "run-vm";
    runtimeInputs = with pkgs; [
      gnugrep
      gnused
      gnutar
      age
      openssh
    ];
    text = /*bash*/ ''

      no_secrets=false
      while getopts 'n' flag; do
        case "$flag" in
          n) no_secrets=true ;;
          *) ;;
        esac
      done
      shift $(( OPTIND - 1 ))

      if [ "$#" -ne 1 ]; then
        echo "Usage: build-vm <hostname>"
        exit 1
      fi
      hostname=$1

      ${config.modules.core.loadNixResourcesKey}

      # Build the VM
      runscript="/home/${username}/result/bin/run-$hostname-vm"
      pushd "/home/${username}" > /dev/null
      reset_dir() {
        popd >/dev/null 2>&1 || true
      }
      trap reset_dir EXIT
      nixos-rebuild build-vm --flake "$flake#$hostname"
      popd > /dev/null

      # Check if the VM uses impermanence
      impermanence=$(nix eval "$flake#nixosConfigurations.$hostname.config.virtualisation.vmVariant.modules.system.impermanence.enable")

      # Reset ssh key early as we no longer need flake access
      if [ -f "$tmp_key" ]; then
        mv "$tmp_key" "$ssh_dir/id_ed25519"
      fi

      # Print ports mapped to the VM
      printf '\nMapped Ports:\n%s\n' "$(grep -o 'hostfwd=[^,]*' "$runscript" | sed 's/hostfwd=//g')"

      if [[ "$no_secrets" = false && ! -e "/home/${username}/$hostname.qcow2" ]]; then
        temp=$(mktemp -d)
        cleanup() {
          rm -rf "$temp"
        }
        trap cleanup EXIT

        # Decrypt the relevant secrets from kit
        kit_path="${../../../hosts/ssh-bootstrap-kit}"
        age -d "$kit_path" | tar -xf - --strip-components=1 -C "$temp" "$hostname"

        # Copy keys to VM
        printf "Copying SSH keys to VM...\nNOTE: Secret decryption will not work on the first VM launch"
        rootDir=""
        if [ "$impermanence" = "true" ]; then
          rootDir="persist"
        fi
        (scp -P 50022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o LogLevel=QUIET -o ConnectionAttempts=30 \
          "$temp/ssh_host_ed25519_key" "$temp/ssh_host_ed25519_key.pub" \
          root@127.0.0.1:"/$rootDir/etc/ssh"; rm -rf "$temp") &
      fi

      # For non-graphical VMs, launch VM and start ssh session in new
      # terminal windows
      if grep -q -- "-nographic" "$runscript"; then
        ${if config.modules.system.desktop.enable then /*bash*/ ''
          ${terminal.exePath} -e "zsh" "-i" "-c" "ssh-vm; zsh -i" &
          ${terminal.exePath} --class qemu -e "$runscript"
        ''
        else "$runscript"}
      else
        $runscript
      fi

    '';
  };
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  config = mkMerge [
    {
      # The vmInstall input flake indicates whether or not we are installing
      # the host in a virtual machine. This is NOT the same as a vmVariant.
      # Matches options in modules/profiles/qemu_guest.nix as conditional
      # imports are not possible.
      boot = mkIf (inputs.vmInstall.value) {
        initrd.availableKernelModules = mkVMOverride [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "sr_mod"
          "virtio_blk"
          "virtio_net"
          "virtio_mmio"
          "virtio_scsi"
          "9p"
          "9pnet_virtio"
        ];
        kernelModules = mkVMOverride [ "kvm-amd" "virtio_balloon" "virtio_console" "virtio_rng" ];
        kernelParams = mkVMOverride [ ];
      };

      # We configure the vmVariant regardless of whether or not the host has
      # virtualisation enabled because it should be possible to create a VM of any host
      virtualisation.vmVariant = {
        device = {
          monitors = mkIf (monitors != [ ]) (mkVMOverride [{
            name = "Virtual-1";
            number = 1;
            refreshRate = 60.0;
            width = 2048;
            height = 1152;
            position.x = 0;
            position.y = 0;
            workspaces = [ 1 2 3 4 5 6 7 8 9 ];
          }]);
          gpu.type = mkVMOverride null;
          hassIntegration.enable = mkVMOverride false;
        };

        modules = {
          system = {
            bluetooth.enable = mkVMOverride false;
            audio.enable = mkVMOverride false;
            virtualisation.libvirt.enable = mkVMOverride false;
            virtualisation.containerisation.enable = mkVMOverride false;
            virtualisation.vmVariant = true;

            networking = {
              primaryInterface = mkVMOverride "eth0";
              staticIPAddress = mkVMOverride null;
              defaultGateway = mkVMOverride null;
              tcpOptimisations = mkVMOverride false;
              wireless.enable = mkVMOverride false;
              firewall.enable = mkVMOverride false;
            };
          };

          services = {
            lact.enable = mkVMOverride false;
            nfs.client.enable = mkVMOverride false;
            nfs.server.enable = mkVMOverride false;
            scrutiny.collector.enable = mkVMOverride false;
            wgnord.enable = mkVMOverride false;
            fail2ban.enable = mkVMOverride false;
            qbittorrent-nox.enable = mkVMOverride false;
            zigbee2mqtt.enable = mkVMOverride false;
            minecraft-server.enable = mkVMOverride false;
            mikrotik-backup.enable = mkVMOverride false;
          };
        };

        virtualisation =
          let
            inherit (config.modules.system) desktop;
          in
          {
            graphics = desktop.enable;
            diskSize = 8192;

            qemu.options = mkIf desktop.enable [
              # Useful resource explaining qemu display device options:
              # https://www.kraxel.org/blog/2019/09/display-devices-in-qemu/#virtio-gpu-pci
              "-device virtio-vga-gl"
              "-display gtk,show-menubar=off,zoom-to-fit=off,gl=on"
            ];

            # Forward all TCP and UDP ports that are opened in the firewall on
            # the default interfaces. Should make the majority of the VMs
            # services accessible from host
            forwardPorts =
              let
                # It's important to use firewall rules from the vmVariant here
                inherit (config.virtualisation.vmVariant.networking.firewall)
                  allowedTCPPorts
                  allowedUDPPorts;
                inherit (config.virtualisation.vmVariant.modules.system.virtualisation)
                  mappedTCPPorts
                  mappedUDPPorts;

                forward = proto: mapped: port: {
                  from = "host";
                  # If not mapped, attempt to map host port to a unique value between 50000-65000
                  host = {
                    port = if mapped then port.hostPort else (mod port 15001) + 50000;
                    address = "127.0.0.1";
                  };
                  guest.port = if mapped then port.vmPort else port;
                  proto = proto;
                };
              in
              map (forward "tcp" false) allowedTCPPorts
              ++
              map (forward "udp" false) allowedUDPPorts
              ++
              map (forward "tcp" true) mappedTCPPorts
              ++
              map (forward "udp" true) mappedUDPPorts;
          };

        programs.zsh.shellAliases.p = "sudo systemctl poweroff";
      };

      microvm.host.enable = cfg.microvm.enable;

      hm = mkIf homeManager.enable {
        desktop.hyprland.settings.windowrulev2 = [
          "workspace name:VM silent, class:^(\.?qemu.*|wlroots|virt-manager)$"
          "float, class:^(\.?qemu.*|virt-manager)$"
          "size 80% 80%, class:^(\.?qemu.*|virt-manager)$"
          "center, class:^(\.?qemu.*|virt-manager)$"
          "keepaspectratio, class:^(\.?qemu.*|virt-manager)$"
        ];
      };
    }

    (mkIf cfg.libvirt.enable {
      environment.systemPackages = [ runVMScript ];
      programs.virt-manager.enable = true;
      users.users.${username}.extraGroups = [ "libvirtd" ];

      environment.sessionVariables =
        let
          memoryStr = toString (if (memory / 4) >= 4096 then 4096 else builtins.floor (memory / 4));
          cores = toString (if (cpu.cores / 2) >= 8 then 8 else builtins.floor (cpu.cores / 2));
        in
        {
          QEMU_OPTS = "-m ${memoryStr} -smp ${cores}";
        };

      hm = mkIf homeManager.enable {
        dconf.settings = {
          "org/virt-manager/virt-manager/connections" = {
            autoconnect = [ "qemu:///system" ];
            uris = [ "qemu:///system" ];
          };
        };
      };

      virtualisation.libvirtd.enable = true;

      programs.zsh.interactiveShellInit = /*bash*/ ''

        ssh-vm() {
          ssh-add-quiet
          echo "Attempting SSH connection to VM..."; 
          # Extra connection attempts as VM may be starting up
          ssh \
            -o "StrictHostKeyChecking=no" \
            -o "UserKnownHostsFile=/dev/null" \
            -o "LogLevel=QUIET" \
            -o "ConnectionAttempts=30" \
            ${username}@127.0.0.1 -p 50022;
        }

      '';

      persistence.directories = [ "/var/lib/libvirt" ];
    })

    (mkIf cfg.containerisation.enable {
      virtualisation.oci-containers.backend = "podman";

      persistence.directories = [ "/var/lib/containers" ];
    })

    (mkIf cfg.microvm.enable {
      persistence.directories = [ "/var/lib/microvms" ];
    })
  ];
}
