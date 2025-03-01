{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  inherit (lib) ns;
  inherit (inputs.nix-resources.secrets) fqDomain;
in
{
  imports = [ ./hardware-configuration.nix ];

  # Pi-3 CPU is too weak for rnnoise-plugin
  programs.noisetorch.enable = true;
  systemd.user.services.noisetorch = {
    description = "Noisetorch Noise Cancelling";
    requires = [ "pipewire.service" ];
    after = [
      "pipewire.service"
      "sys-devices-platform-soc-3f980000.usb-usb1-1\x2d1-1\x2d1.3-1\x2d1.3:1.0-sound-card2-controlC2.device"
    ];
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = "!@system";
    serviceConfig =
      let
        noisetorch = lib.getExe config.programs.noisetorch.package;
      in
      {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${noisetorch} -i -s alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_201306-00.mono-fallback -t 95";
        ExecStop = "${noisetorch} -u";
        Restart = "on-failure";
        RestartSec = 3;
      };
  };

  ${ns} = {
    userPackages = with pkgs; [
      pulseaudio
      btop
      ffmpeg
    ];

    hardware.file-system.type = "sd-image";

    core = {
      home-manager.enable = false;

      device = {
        type = "server";
        ipAddress = "10.20.20.28";
        memory = 1024;

        cpu = {
          name = "Cortex-A53";
          type = "arm";
          cores = "4";
        };
      };
    };

    services = {
      restic.enable = true;
      restic.backupSchedule = "*-*-* 03:00:00";
      zigbee2mqtt = {
        enable = false;
        address = "0.0.0.0";
        mqtt.server = "mqtts://mqtt.${fqDomain}:8883";
        deviceNode = "/dev/ttyACM0";
      };
    };

    system = {
      audio.enable = true;
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
}
