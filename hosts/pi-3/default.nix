{ pkgs, inputs, ... }:
let
  inherit (inputs.nix-resources.secrets) fqDomain;
in
{
  imports = [ ./hardware-configuration.nix ];

  device = {
    type = "desktop";
    ipAddress = "192.168.88.220";
    memory = 1024;

    cpu = {
      name = "Cortex-A53";
      type = "arm";
      cores = "4";
    };
  };

  modules = {
    core.homeManager.enable = false;
    hardware.fileSystem.type = "sd-image";

    services = {
      restic.enable = true;
      restic.backupSchedule = "*-*-* 03:00:00";
      zigbee2mqtt = {
        enable = true;
        mqtt.server = "mqtt://mqtt.${fqDomain}:8883";
        deviceNode = "/dev/ttyACM0";
      };
    };

    system = {
      ssh.server.enable = true;
      # Cross compilation build fails
      ssh.agent.enable = false;

      networking = {
        primaryInterface = "enu1u1u1";
        useNetworkd = true;
        wireless = {
          enable = true;
          interface = "wlan0";
        };
      };
    };
  };

  environment.systemPackages = [ pkgs.btop ];
}
