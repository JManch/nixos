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
        ipAddress = "192.168.100.11";
        memory = 1024 * 64;
        backlight = "amdgpu_bl1";
        battery = "BAT1";

        cpu = {
          name = "AI 9 HX 370";
          type = "amd";
          cores = 24;
        };

        monitors = [
          {
            name = "eDP-1";
            number = 1;
            refreshRate = 120.0;
            width = 2880;
            height = 1920;
            scale = 1.5;
            position.x = 0;
            position.y = 0;
            workspaces = builtins.genList (i: i + 1) 50;
          }
        ];
      };
    };

    hardware = {
      secure-boot.enable = true;
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
      gaming = {
        enable = true;
        steam.enable = true;
      };
    };

    services = {
      wireguard = {
        home = {
          enable = true;
          autoStart = false;
          address = "192.168.100.11";
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

        friends = {
          enable = true;
          autoStart = false;
          address = "10.0.0.11";
          subnet = 24;

          peers = lib.singleton {
            publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
            presharedKeyFile = config.age.secrets.wg-friends-router-psk.path;
            allowedIPs = [ "10.0.0.0/24" ];
            endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString inputs.nix-resources.secrets.friendsWgRouterPort}";
          };

          dns = {
            enable = true;
            address = "10.0.0.7";
            domains.${inputs.nix-resources.secrets.tomFqDomain} = "";
          };
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
          interface = "wlp192s0";
        };
      };
    };
  };
}
