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
      nix.builder.enable = true;

      device = {
        type = "laptop";
        address = "10.20.20.23";
        vpnAddress = "192.168.100.11";
        memory = 1024 * 48; # lost 16 to VRAM
        backlight = "amdgpu_bl1";
        battery = "BAT1";

        cpu = {
          name = "AI 9 HX 370";
          type = "amd";
          cores = 24;
        };

        gpu = {
          name = "Radeon 890M";
          type = "amd";
          hwmonId = 1;
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

      keyd.rebinds = {
        capslock = "layer(control)";
        leftcontrol = "capslock";
        leftmeta = "layer(alt)";
        leftalt = "layer(meta)";
        rightcontrol = "layer(altgr)";
        rightalt = "rightmeta";
      };
    };

    programs = {
      winbox.enable = true;
      gaming = {
        enable = true;
        steam.enable = true;
        gamescope.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      udisks.enable = true;
      wgnord.enable = true;
      mosquitto.explorer.enable = true;

      wireguard = {
        home = {
          enable = true;
          trustedSSIDs = [ inputs.nix-resources.secrets.homeSSID ];
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
      virtualisation.libvirt.enable = true;

      ssh.server = {
        enable = true;
        extraInterfaces = [ "wlp192s0" ];
      };

      audio = {
        enable = true;
        alsaDeviceAliases = {
          "alsa_output.pci-0000_c1_00.6.analog-stereo" = "Laptop Audio";
          "alsa_input.pci-0000_c1_00.6.analog-stereo" = "Laptop Microphone";
        };
      };

      desktop = {
        enable = true;
        desktopEnvironment = null;
        displayManager.name = "uwsm";
        displayManager.autoLogin = true;
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
