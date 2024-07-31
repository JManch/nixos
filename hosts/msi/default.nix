{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  device = {
    type = "desktop";
    ipAddress = null;
    memory = 16000;

    cpu = {
      name = "i7 6700k";
      type = "intel";
      cores = "8";
    };

    gpu = {
      name = "RTX 2070";
      type = "nvidia";
    };

    monitors = [
      {
        name = "placeholder";
        number = 1;
        refreshRate = 60;
        width = 1920;
        height = 1080;
        position.x = 0;
        position.y = 0;
      }
    ];
  };

  modules = {
    core = {
      priviledgedUser = false;
      homeManager.enable = true;
      autoUpgrade = true;
    };

    hardware = {
      fileSystem = {
        type = "zfs";
        tmpfsTmp = true;
        zfs.trim = true;
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    system = {
      impermanence.enable = false;
      audio.enable = true;
      ssh.server.enable = true;
      networking.primaryInterface = "enp3s0";

      windows.bootEntry = {
        enable = true;
        fsAlias = "HD0b65535a1";
      };

      desktop = {
        enable = true;
        # Suspend is very close to being stable but it sometimes causes
        # applications to crash and the system sometimes gets stuck in a
        # suspend loop
        suspend.enable = false;
        desktopEnvironment = "gnome";
      };
    };

    programs = {
      gaming = {
        enable = true;
        steam.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      restic = {
        enable = true;
        backupSchedule = "*-*-* 14:00:00";
        runMaintenance = false;
      };
    };
  };
}
