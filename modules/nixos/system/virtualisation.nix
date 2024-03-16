{ lib
, pkgs
, config
, username
, ...
} @ args:
let
  inherit (lib) utils mkIf mkMerge mkVMOverride mod optionals;
  inherit (homeConfig.modules.desktop) terminal;
  homeConfig = utils.homeConfig args;
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

      if [ -z "$1" ]; then
        echo "Usage: build-vm <hostname>"
        exit 1
      fi
      hostname=$1

      # Build the VM
      runscript="/home/${username}/result/bin/run-$hostname-vm"
      cd
      sudo nixos-rebuild build-vm --flake "/home/${username}/.config/nixos#$hostname"

      # Print ports mapped to the VM
      printf '\nMapped Ports:\n%s' "$(grep -o 'hostfwd=[^,]*' "$runscript" | sed 's/hostfwd=//g')"

      if [[ ! -e "/home/${username}/$hostname.qcow2" ]]; then
        # Decrypt the relevant secrets from kit
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

        echo
        age -d -o "$temp/ssh-bootstrap-kit.tar" "$kit_path"
        tar -xf "$temp/ssh-bootstrap-kit.tar" --strip-components=1 -C "$temp" "$hostname"
        rm -f "$temp/ssh-bootstrap-kit.tar"

        # Copy keys to VM
        printf "Copying SSH keys to VM...\nNOTE: Secret decryption will not work on the first VM launch"
        (scp -P 50022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o LogLevel=QUIET -o ConnectionAttempts=30 \
          "$temp/ssh_host_ed25519_key" "$temp/ssh_host_ed25519_key.pub" \
          root@127.0.0.1:/persist/etc/ssh; rm -rf "$temp") &
      fi

      # For non-graphical VMs, launch VM and start ssh session in new
      # terminal windows
      if grep -q -- "-nographic" "$runscript"; then
        ${if config.usrEnv.desktop.enable then /*bash*/ ''
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
mkMerge [
  {
    # We configure the vmVariant regardless of whether or not the host has
    # virtualisation enabled because it should be possible to create a VM of any host
    virtualisation.vmVariant = {
      device = {
        monitors = mkIf (config.device.monitors != [ ]) (mkVMOverride [{
          name = "Virtual-1";
          number = 1;
          refreshRate = 60.0;
          width = 2048;
          height = 1152;
          position = "0x0";
          workspaces = [ 1 2 3 4 5 6 7 8 9 ];
        }]);
        gpu.type = mkVMOverride null;
      };

      modules = {
        system = {
          bluetooth.enable = mkVMOverride false;
          audio.enable = mkVMOverride false;
          virtualisation.enable = mkVMOverride false;
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
      };

      virtualisation =
        let
          desktopEnabled = config.usrEnv.desktop.enable;
        in
        {
          # TODO: Make this modular based on host spec. Ideally would base this
          # on the host we are running the VM on but I don't think that's
          # possible? Could be logical to simulate the exact specs of the host
          # we are replicating, although that won't always be feasible
          # depending the actual host we are running the vm on. Could work
          # around this by instead modifying the generated launch script in our
          # run-vm zsh function.
          # We can solve this by storing the currents hosts specs in env vars.
          memorySize = 4096;
          cores = 8;
          graphics = desktopEnabled;
          qemu = {
            options = optionals desktopEnabled [
              # Allows nixos-rebuild build-vm graphical session
              # https://github.com/NixOS/nixpkgs/issues/59219
              "-device virtio-vga-gl"
              "-display gtk,show-menubar=off,gl=on"
            ];
          };
          # Forward all TCP and UDP ports that are opened in the firewall on
          # the default interfaces. Should make the majority of the VMs
          # services accessible from host
          # TODO: Add a "vmVariant.firewallInterfaces" option that lists
          # interfaces to expose from the VM variant. Might need to remove
          # duplicate ports, not sure if it's an issue to open same port
          # multiple times?
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
    };
  }

  (mkIf cfg.enable {
    environment.systemPackages = [ runVMScript ];
    programs.virt-manager.enable = true;
    users.users.${username}.extraGroups = [ "libvirtd" "docker" ];

    hm.dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = [ "qemu:///system" ];
        uris = [ "qemu:///system" ];
      };
    };

    virtualisation = {
      libvirtd.enable = true;
      # TODO: Properly configure docker
      docker.enable = false;
    };

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
]
