{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  ${lib.ns} = {
    core = {
      home-manager.enable = true;

      device = {
        type = "laptop";
        ipAddress = "192.168.100.10";
        memory = 1024 * 8;
        backlight = "intel_backlight";
        battery = "BAT1";

        cpu = {
          name = "i5 7300U";
          type = "intel";
          cores = 4;
        };

        monitors = [
          {
            name = "eDP-1";
            number = 1;
            refreshRate = 60.0;
            width = 2736;
            height = 1824;
            scale = 1.5;
            position.x = 0;
            position.y = 0;
            workspaces = builtins.genList (i: i + 1) 50;
          }
        ];
      };
    };

    hardware = {
      bluetooth.enable = true;

      file-system = {
        type = "ext4";
        ext4.trim = true;
      };

      keyd = {
        enable = true;
        swapCapsControl = true;
        swapAltMeta = true;
        excludedDevices = [
          "04fe:0021:5b3ab73a" # HHKB
        ];
      };
    };

    programs = {
      winbox.enable = true;
    };

    services = {
      wireguard.home = {
        enable = true;
        autoStart = true;
        address = "192.168.100.10";
        subnet = 24;

        peers = lib.singleton {
          publicKey = "4kLZt3aTWUbqSZhz5Q64izTwA4qrDfnkso0z8gRfJ1Q=";
          presharedKeyFile = config.age.secrets.wg-home-router-psk.path;
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString inputs.nix-resources.secrets.homeWgRouterPort}";
        };

        dns = {
          enable = true;
          address = "192.168.100.1";
        };
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      audio.enable = true;

      desktop = {
        enable = true;
        desktopEnvironment = null;
        displayManager.name = "uwsm";
        uwsm.defaultDesktop = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
      };

      networking = {
        tcpOptimisations = true;
        resolved.enable = true;

        firewall = {
          enable = true;
          defaultInterfaces = [ "wg-home" ];
        };

        wireless = {
          enable = true;
          onlyWpa2 = true;
          interface = "wlp1s0";
        };
      };
    };
  };
}
