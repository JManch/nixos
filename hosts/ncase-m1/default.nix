{ username, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostId = "625ec505";

  device = {
    type = "desktop";
    ipAddress = "192.168.88.254";
    memory = 32000;

    cpu = {
      name = "R7 3700x";
      type = "amd";
      cores = 16;
    };

    gpu = {
      name = "RX 7900XT";
      type = "amd";
      hwmonId = 2;
    };

    monitors = [
      {
        name = "DP-1";
        number = 1;
        refreshRate = 144.0;
        gamingRefreshRate = 165.0;
        gamma = 0.75;
        width = 2560;
        height = 1440;
        position = "2560x0";
        workspaces = [ 1 3 5 7 9 ];
      }
      {
        name = "HDMI-A-1";
        number = 2;
        refreshRate = 59.951;
        width = 2560;
        height = 1440;
        position = "0x0";
        workspaces = [ 2 4 6 8 ];
      }
      {
        # Enabled on-demand for sim racing
        enabled = false;
        name = "DP-2";
        mirror = "DP-1";
        number = 3;
        refreshRate = 59.951;
        width = 2560;
        height = 1440;
        position = "-2560x0";
        transform = 2;
      }
    ];
  };

  usrEnv = {
    homeManager.enable = true;

    desktop = {
      enable = true;
      desktopEnvironment = null;
    };
  };

  modules = {
    hardware = {
      secureBoot.enable = true;
      vr.enable = false;
      fanatec.enable = true;

      fileSystem = {
        trim = true;
        bootLabel = "boot";
        zpoolName = "zpool";
        unstableZfs = true;
        forceImportRoot = false;
      };
    };

    programs = {
      wine.enable = true;
      winbox.enable = true;
      matlab.enable = true;
      wireshark.enable = true;

      gaming = {
        enable = true;
        steam.enable = true;
        gamescope.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      udisks.enable = true;
      ollama.enable = false; # FIX: waiting for nixpkgs update
      broadcast-box.enable = true;
      greetd.enable = true;
      lact.enable = true;
      scrutiny.collector.enable = true;

      wgnord = {
        enable = true;
        excludeSubnets = [ "192.168.89.2/32" ];
      };

      wireguard.friends = {
        enable = true;
        routerPeer = true;
        routerAllowedIPs = [ "10.0.0.0/24" ];
        address = "10.0.0.2";
        subnet = 24;
        dns = {
          enable = true;
          address = "10.0.0.7";
        };
      };

      jellyfin = {
        enable = true;
        autoStart = false;
        mediaDirs = {
          shows = "/home/${username}/videos/shows";
          movies = "/home/${username}/videos/movies";
        };
      };

      nfs.client = {
        enable = true;
        supportedMachines = [ "homelab.lan" ];
      };
    };

    system = {
      windows.enable = true;
      bluetooth.enable = true;
      virtualisation.enable = true;

      networking = {
        primaryInterface = "eno1";
        defaultGateway = "192.168.88.1";
        tcpOptimisations = true;
        resolved.enable = true;
        firewall.enable = true;

        wireless = {
          enable = true;
          interface = "wlp6s0";
          disableOnBoot = true;
        };
      };

      audio = {
        enable = true;
        extraAudioTools = true;
      };
    };
  };
}
