{
  lib,
  pkgs,
  inputs,
  config,
  username,
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
        type = "desktop";
        address = "192.168.88.254";
        vpnAddress = "192.168.100.12";
        altAddresses = [
          "10.20.20.11" # wireless interface
        ];
        memory = 1024 * 64;
        # hassIntegration.enable = true;

        cpu = {
          name = "R7 3700x";
          type = "amd";
          threads = 16;
        };

        gpu = {
          name = "RX 7900XT";
          type = "amd";
          hwmonId = 2;
        };

        monitors = [
          {
            # DP-1 is rightmost port, furthest from HDMI
            # Use DP-3 (port next to HDMI) for VR headset
            name = "DP-1";
            number = 1;
            refreshRate = 144.0;
            gamingRefreshRate = 165.0;
            gamma = 0.75;
            width = 2560;
            height = 1440;
            position.x = 2560;
            position.y = 0;
            workspaces = builtins.genList (i: (i * 2) + 1) 25;
          }
          # {
          #   name = "HDMI-A-1";
          #   number = 2;
          #   refreshRate = 59.951;
          #   width = 2560;
          #   height = 1440;
          #   position.x = 0;
          #   position.y = 0;
          #   workspaces = builtins.genList (i: (i * 2) + 2) 25;
          # }
          # {
          #   # Enabled on-demand for sim racing
          #   enabled = false;
          #   name = "DP-2";
          #   mirror = "DP-1";
          #   number = 3;
          #   refreshRate = 59.951;
          #   width = 2560;
          #   height = 1440;
          #   position.x = -2560;
          #   position.y = 0;
          #   transform = 2;
          # }
        ];
      };

      nix.builder = {
        enable = true;
        emulatedSystems = [ "aarch64-linux" ];
      };
    };

    hardware = {
      secure-boot.enable = true;
      bluetooth.enable = true;
      fanatec.enable = true;
      tablet.enable = true;
      scanner.enable = true;

      valve-index = {
        enable = true;
        audio = {
          card = "alsa_card.pci-0000_09_00.1";
          profile = "output:hdmi-stereo-extra1";
          source = "alsa_input.usb-Valve_Corporation_Valve_VR_Radio___HMD_Mic_8BABED88E1-LYM-01.mono-fallback";
          sink = "alsa_output.pci-0000_09_00.1.hdmi-stereo-extra1";
        };
      };

      file-system = {
        type = "zfs";
        zfs.trim = true;
        zfs.unstable = false;
        zfs.encryption.passphraseCred = inputs.nix-resources.secrets.zfsPassphrases.ncase-m1;
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    programs = {
      wine.enable = true;
      winbox.enable = true;
      matlab.enable = false;
      adb.enable = true;

      wireshark = {
        enable = true;
        graphical = true;
      };

      gaming = {
        enable = true;
        steam.enable = true;
        steam.lanTransfer = false;
        gamescope.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      udisks.enable = true;
      lact.enable = true;
      scrutiny.collector.enable = true;
      mosquitto.explorer.enable = true;
      air-vpn.enable = true;

      ollama = {
        enable = false; # open-webui build failure
        openFirewall = true;
      };

      jellyfin = {
        enable = false;
        openFirewall = true;
        autoStart = false;
        backup = false;
        mediaDirs.shows = "/home/${username}/videos/shows";
      };

      wgnord = {
        enable = true;
        excludeSubnets = [ "192.168.89.2/32" ];
      };

      wireguard = {
        home = {
          enable = true;
          autoStart = true;
          address = "192.168.100.12";
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
          autoStart = true;
          address = "10.0.0.2";
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

      nfs.client = {
        enable = false;
        supportedMachines = [ "homelab.lan" ];
      };

      satisfactory-server = {
        enable = false;
        autoStart = false;
        interfaces = [ "wg-friends" ];
      };

      file-server.uploadAlias = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      virtualisation.libvirt.enable = true;

      backups.restic = {
        enable = true;
        timerConfig = {
          OnCalendar = "*-*-* 15:00:00";
          Persistent = true;
        };
      };

      desktop = {
        enable = true;
        desktopEnvironment = null;
        displayManager.name = "uwsm";
        uwsm.defaultDesktop = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
      };

      networking = {
        wiredInterface = "eno1";
        defaultGateway = "192.168.88.1";
        tcpOptimisations = true;
        resolved.enable = true;
        eduroam.enable = true;

        firewall = {
          enable = true;
          defaultInterfaces = [ "wg-home" ];
        };

        wireless = {
          enable = true;
          interface = "wlp6s0";
          disableOnBoot = false;
        };
      };

      audio = {
        enable = true;
        defaultSource = "alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_201306-00.mono-fallback";
        defaultSink = "alsa_output.pci-0000_0b_00.4.analog-stereo";

        alsaDeviceAliases = {
          "alsa_input.usb-BLUE_MICROPHONE_Blue_Snowball_201306-00.mono-fallback" = "Blue Snowball";
          "alsa_output.pci-0000_0b_00.4.analog-stereo" = "Headphones";
          "alsa_output.pci-0000_09_00.1.hdmi-stereo" = "Dell Monitor";
          "alsa_output.pci-0000_09_00.1.hdmi-stereo-extra3" = "Asus Monitor";
        };
      };
    };
  };
}
