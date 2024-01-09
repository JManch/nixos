{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "desktop";
    cpu = "amd";
    gpu = "amd";
    monitors = [
      {
        name = "DP-1";
        number = 1;
        refreshRate = 144.0;
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
      desktopManager = null;
    };
  };

  modules = {
    hardware = {
      fileSystem = {
        trim = true;
        rootTmpfsSize = "4G";
        zpoolName = "zpool";
        bootLabel = "boot";
      };
    };

    programs = {
      wine.enable = false;
      winbox.enable = true;
      steam.enable = true;
    };

    services = {
      greetd = {
        enable = true;
        launchCmd = "Hyprland";
      };
      # Broken cause of syncthing-init service
      syncthing.enable = false;
      wgnord.enable = true;
    };

    system = {
      windowsBootEntry.enable = true;
      networking = {
        tcpOptimisations = true;
        firewall.enable = true;
        resolved.enable = true;
      };
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
