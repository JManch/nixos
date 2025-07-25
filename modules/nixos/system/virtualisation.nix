{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  username,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    mkVMOverride
    mod
    mkEnableOption
    optional
    mkOption
    types
    ;
  inherit (config.${ns}.core.device)
    monitors
    cpu
    memory
    primaryMonitor
    ;
  inherit (config.${ns}.hmNs.desktop) hyprland;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) desktop;

  runVMScript = pkgs.writeShellApplication {
    name = "run-vm";
    runtimeInputs =
      (with pkgs; [
        gnugrep
        gnused
        gnutar
        age
        openssh
        xdg-terminal-exec
      ])
      ++ [ pkgs.${ns}.bootstrap-kit ];
    text = ''
      no_secrets=false
      while getopts 'n' flag; do
        case "$flag" in
          n) no_secrets=true ;;
          *) ;;
        esac
      done
      shift $(( OPTIND - 1 ))

      if [ "$#" -ne 1 ]; then
        echo "Usage: run-vm <hostname>"
        exit 1
      fi
      hostname=$1

      flake="/home/${username}/.config/nixos"
      if [ ! -d $flake ]; then
        echo "Flake does not exist locally so using remote from github"
        flake="github:JManch/nixos"
      fi

      ${lib.${ns}.exitTrapBuilder}

      # Build the VM
      runscript="/home/${adminUsername}/result/bin/run-$hostname-vm"
      pushd "/home/${adminUsername}" > /dev/null
      add_exit_trap "popd >/dev/null 2>&1 || true"
      nixos-rebuild build-vm --flake "$flake#$hostname"

      # Check if the VM uses impermanence
      impermanence=$(nix eval "$flake#nixosConfigurations.$hostname.config.virtualisation.vmVariant.${ns}.system.impermanence.enable")

      # Print ports mapped to the VM
      printf '\nMapped Ports:\n%s\n' "$(grep -o 'hostfwd=[^,]*' "$runscript" | sed 's/hostfwd=//g')"

      if [[ "$no_secrets" = false && ! -e "/home/${adminUsername}/$hostname.qcow2" ]]; then
        bootstrap_kit=$(mktemp -d)
        # shellcheck disable=SC2016
        add_exit_trap 'sudo rm -rf $bootstrap_kit'

        sudo bootstrap-kit decrypt "$bootstrap_kit"

        # Copy keys to VM
        printf "Copying SSH keys to VM...\nNOTE: Secret decryption will not work on the first VM launch"
        rootDir=""
        if [ "$impermanence" = "true" ]; then
          rootDir="persist"
        fi
        (sudo scp -P 50022 -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET -o ConnectionAttempts=30 \
          "$bootstrap_kit/$hostname/ssh_host_ed25519_key" "$bootstrap_kit/$hostname/ssh_host_ed25519_key.pub" \
          root@127.0.0.1:"/$rootDir/etc/ssh"; rm -rf "$bootstrap_kit") &
      fi

      # For non-graphical VMs, launch VM and start ssh session in new
      # terminal windows
      if grep -q -- "-nographic" "$runscript"; then
        ${
          if config.${ns}.system.desktop.enable && home-manager.enable then # bash
            ''
              xdg-terminal-exec "zsh" "-i" "-c" "ssh-vm; zsh -i" &
              xdg-terminal-exec --app-id=qemu -e "$runscript"
            ''
          else
            "$runscript"
        }
      else
        $runscript
      fi
    '';
  };
in
[
  {
    enableOpt = false;

    opts = {
      libvirt.enable = mkEnableOption "libvirt virtualisation";

      vmVariant = mkOption {
        type = types.bool;
        internal = true;
        default = false;
      };

      mappedTCPPorts = mkOption {
        type = with types; listOf (attrsOf port);
        default = [ ];
        example = [
          {
            vmPort = 8999;
            hostPort = 9003;
          }
        ];
        description = ''
          Map TCP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };

      mappedUDPPorts = mkOption {
        type = with types; listOf (attrsOf port);
        default = [ ];
        example = [
          {
            vmPort = 8999;
            hostPort = 9003;
          }
        ];
        description = ''
          Map UDP ports from VM to host. Forceful alternative to opening the
          firewall as it does not attempt to avoid clashes by mapping port into
          50000-65000 range.
        '';
      };
    };

    # The vmInstall input flake indicates whether or not we are installing
    # the host in a virtual machine. This is NOT the same as a vmVariant.
    # Matches options in modules/profiles/qemu_guest.nix.
    boot = mkIf inputs.vmInstall.value {
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
      kernelModules = mkVMOverride [
        "kvm-amd"
        "virtio_balloon"
        "virtio_console"
        "virtio_rng"
      ];
      kernelParams = mkVMOverride [ ];
    };

    # We configure the vmVariant regardless of whether or not the host has
    # virtualisation enabled because it should be possible to create a VM of any host
    virtualisation.vmVariant = {
      # Otherwise VM fails to start
      boot.resumeDevice = mkVMOverride "";

      ${ns} = {
        core.device = {
          monitors = mkIf (monitors != [ ]) (mkVMOverride [
            {
              name = "Virtual-1";
              number = 1;
              refreshRate = 60.0;
              width = builtins.floor (0.75 * primaryMonitor.width);
              height = builtins.floor (0.75 * primaryMonitor.height);
              position.x = 0;
              position.y = 0;
              workspaces = builtins.genList (i: i + 1) 9;
            }
          ]);
          gpu.type = mkVMOverride null;
          hassIntegration.enable = mkVMOverride false;
        };

        hardware = {
          bluetooth.enable = mkVMOverride false;
          printing.client.enable = mkVMOverride false;
          valve-index.enable = mkVMOverride false;
        };

        system = {
          audio.enable = mkVMOverride false;
          virtualisation.libvirt.enable = mkVMOverride false;
          virtualisation.vmVariant = true;
          backups.ssidBlacklist = mkVMOverride [ ];

          networking = {
            wiredInterface = mkVMOverride "eth0";
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
          torrent-stack.video.enable = mkVMOverride false;
          torrent-stack.music.enable = mkVMOverride false;
          zigbee2mqtt.enable = mkVMOverride false;
          minecraft-server.enable = mkVMOverride false;
          mikrotik-backup.enable = mkVMOverride false;
          index-checker.enable = mkVMOverride false;
          ollama.enable = mkVMOverride false;
        };
      };

      virtualisation =
        let
          inherit (config.${ns}.system) desktop;
        in
        {
          useDefaultFilesystems = true;
          graphics = desktop.enable;
          diskSize = 8192;

          qemu.options = mkIf desktop.enable [
            # Useful resource explaining qemu display device options:
            # https://www.kraxel.org/blog/2019/09/display-devices-in-qemu/#virtio-gpu-pci
            "-device virtio-vga-gl"
            # FIX: Something regressed TTY resolution with the GTK display
            # type between qemu 9.1.2 and 9.2.0. Using SDL till it's fixed.
            # "-display gtk,show-menubar=off,zoom-to-fit=off,gl=on"
            "-display sdl,gl=on"
            # Alternative method using spice that should enable clipboard
            # sharing once wayland support gets added:
            # https://gitlab.freedesktop.org/spice/linux/vd_agent/-/issues/26
            # WARN: This needs the virt-viewer package installed and maybe spice?
            # Also needs services.spice-vdagentd enabled in the vmVariant

            # "-spice unix=on,disable-ticketing=on"
            # "-display spice-app,gl=on"
            # "-device virtio-vga-gl"
            # "-device virtio-serial-pci -chardev spicevmc,id=vdagent,debug=0,name=vdagent"
            # "-device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
          ];

          # Forward all TCP and UDP ports that are opened in the firewall on
          # the default interfaces. Should make the majority of the VMs
          # services accessible from host
          forwardPorts =
            let
              # It's important to use firewall rules from the vmVariant here
              inherit (config.virtualisation.vmVariant.networking.firewall) allowedTCPPorts allowedUDPPorts;
              inherit (config.virtualisation.vmVariant.${ns}.system.virtualisation)
                mappedTCPPorts
                mappedUDPPorts
                ;

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
            ++ map (forward "udp" false) allowedUDPPorts
            ++ map (forward "tcp" true) mappedTCPPorts
            ++ map (forward "udp" true) mappedUDPPorts;
        };

      programs.zsh.shellAliases.p = "sudo systemctl poweroff";
    };

    ns.hm = mkIf home-manager.enable {
      ${ns}.desktop.hyprland = {
        namedWorkspaces.VM = "monitor:${primaryMonitor.name}";

        settings =
          let
            inherit (hyprland) modKey namedWorkspaceIDs;
          in
          {
            bind = [
              "${modKey}, V, workspace, ${namedWorkspaceIDs.VM}"
              "${modKey}SHIFT, V, movetoworkspace, ${namedWorkspaceIDs.VM}"
            ];

            windowrule = [
              "workspace ${namedWorkspaceIDs.VM} silent, class:^(\\.?qemu.*|aquamarine|\\.virt-manager-wrapped)$"
              "float, class:^(\\.?qemu.*|\\.virt-manager-wrapped)$"
              "size 80% 80%, class:^(\\.?qemu.*|\\.virt-manager-wrapped)$"
              "center, class:^(\\.?qemu.*|\\.virt-manager-wrapped)$"
              "keepaspectratio, class:^(\\.?qemu.*|\\.virt-manager-wrapped)$"
            ];
          };
      };
    };

    ns.adminPackages = optional desktop.enable runVMScript;
  }

  (mkIf cfg.libvirt.enable {
    programs.virt-manager.enable = true;
    users.users.${username}.extraGroups = [ "libvirtd" ];

    environment.sessionVariables =
      let
        memoryStr = toString (if (memory / 4) >= 4096 then 4096 else builtins.floor (memory / 4));
        threads = toString (if (cpu.threads / 2) >= 8 then 8 else builtins.floor (cpu.threads / 2));
      in
      {
        QEMU_OPTS = "-m ${memoryStr} -smp ${threads}";
      };

    ns.hm = mkIf home-manager.enable {
      dconf.settings = {
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = [ "qemu:///system" ];
          uris = [ "qemu:///system" ];
        };
      };
    };

    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      onShutdown = "shutdown";
    };

    programs.zsh.interactiveShellInit = # bash
      ''
        ssh-vm() {
          echo "Attempting SSH connection to VM..."; 
          # Extra connection attempts as VM may be starting up
          ssh \
            -o "StrictHostKeyChecking=no" \
            -o "UserKnownHostsFile=/dev/null" \
            -o "LogLevel=QUIET" \
            -o "ConnectionAttempts=30" \
            ${adminUsername}@127.0.0.1 -p 50022;
        }
      '';

    systemd.tmpfiles.rules = [
      "d /tmp/tmp-vms 0777 root root - -"
    ];

    ns.persistence.directories = [ "/var/lib/libvirt" ];
  })

  (mkIf (config.virtualisation.oci-containers.containers != { }) {
    virtualisation.oci-containers.backend = "podman";

    ns.persistence.directories = [ "/var/lib/containers" ];
  })
]
