{
  ns,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nix-resources.secrets) fqDomain;
in
{
  imports = [ ./hardware-configuration.nix ];

  ${ns} = {
    core.homeManager.enable = false;
    hardware.fileSystem.type = "sd-image";

    device = {
      type = "desktop";
      ipAddress = "10.20.20.28";
      memory = 1024;

      cpu = {
        name = "Cortex-A53";
        type = "arm";
        cores = "4";
      };
    };

    services = {
      restic.enable = true;
      restic.backupSchedule = "*-*-* 03:00:00";
      zigbee2mqtt = {
        enable = true;
        address = "0.0.0.0";
        mqtt.server = "mqtts://mqtt.${fqDomain}:8883";
        deviceNode = "/dev/ttyACM0";
      };
    };

    system = {
      ssh.server.enable = true;
      # Cross compilation build fails
      ssh.agent.enable = false;

      networking = {
        wiredInterface = "enu1u1u1";
        useNetworkd = true;
        resolved.enable = true;

        firewall = {
          enable = true;
          defaultInterfaces = [
            "enu1u1u1"
            "wlan0"
          ];
        };

        wireless = {
          enable = true;
          interface = "wlan0";
        };
      };
    };
  };

  # Drop all traffic to port 8084 not originating from 192.168.89.2
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw -p tcp --dport 8084 ! -s 192.168.89.2 -j nixos-fw-refuse
  '';

  environment.systemPackages = [ pkgs.btop ];
}
