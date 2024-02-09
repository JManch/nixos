{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "desktop";
    cpu = {
      name = "R7 3700x";
      type = "amd";
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
      fileSystem = {
        trim = true;
        zpoolName = "zpool";
        bootLabel = "boot";
      };
      # Not ready yet
      vr.enable = false;
    };

    programs = {
      wine.enable = false;
      winbox.enable = true;
      gaming = {
        enable = true;
        windowClassRegex = "^(steam_app.*|cs2|\.gamescope.*|bfv\.exe)$";
        steam.enable = true;
        gamescope.enable = true;
        gamemode.enable = true;
      };
      matlab.enable = true;
    };

    services = {
      greetd = {
        enable = true;
        launchCmd = "Hyprland";
      };
      # Broken cause of syncthing-init service
      syncthing.enable = false;
      wgnord.enable = true;
      udisks2.enable = true;
      wireguard.enable = true;
      jellyfin = {
        enable = true;
        autoStart = false;
      };
    };

    system = {
      windows.enable = true;
      networking = {
        tcpOptimisations = true;
        firewall.enable = true;
        resolved.enable = true;
        wireless.enable = true;
      };
      bluetooth.enable = true;
      audio = {
        enable = true;
        extraAudioTools = true;
      };
      virtualisation.enable = true;
    };
  };

  networking.hostId = "625ec505";

  system.stateVersion = "23.05";
}
