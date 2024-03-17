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

      fileSystem = {
        trim = true;
        bootLabel = "boot";
        zpoolName = "zpool";
        forceImportRoot = false;
      };
    };

    programs = {
      wine.enable = true;
      winbox.enable = true;
      matlab.enable = true;

      gaming = {
        enable = true;
        steam.enable = true;
        gamescope.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      wgnord.enable = true;
      udisks.enable = true;
      wireguard.enable = true;
      ollama.enable = false; # FIX: waiting for nixpkgs update
      broadcast-box.enable = true;
      greetd.enable = true;
      corectrl.enable = false;
      lact.enable = true;

      jellyfin = {
        enable = true;
        autoStart = false;
      };
    };

    system = {
      windows.enable = true;
      bluetooth.enable = true;
      virtualisation.enable = true;

      networking = {
        primaryInterface = "eno1";
        tcpOptimisations = true;
        resolved.enable = true;

        wireless = {
          enable = true;
          disableOnBoot = true;
        };

        firewall.enable = true;
      };

      audio = {
        enable = true;
        extraAudioTools = true;
      };
    };
  };
}
