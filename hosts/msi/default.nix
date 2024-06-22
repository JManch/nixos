{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  device = {
    type = "desktop";
    ipAddress = null; # TODO:
    memory = 16000;

    cpu = {
      name = "i7 6700k";
      type = "intel";
      cores = "8";
    };

    # gpu = {
    #   name = "RTX 2070";
    #   type = "nvidia";
    # };

    monitors = [{
      name = "UNKNOWN"; # TODO:
      number = 1;
      refreshRate = 60;
      width = 1920; # TODO:
      height = 1080; # TODO:
      position.x = 0;
      position.y = 0;
    }];
  };

  usrEnv.homeManager.enable = false;

  modules = {
    core = {
      autoUpgrade = true;
    };

    hardware = {
      fileSystem = {
        trim = true;
        forceImportRoot = true; # TODO: set this to false
      };
      # TODO: Delete this when I configure GPU again
      graphics.hardwareAcceleration = true;
    };

    # programs = {
    #   gaming = {
    #     enable = true;
    #     steam.enable = true;
    #     gamemode.enable = true;
    #   };
    # };

    services = {
      # restic = {
      #   enable = true;
      #   backupSchedule = "*-*-* 15:00:00";
      # };
    };

    system = {
      impermanence.enable = false;

      desktop = {
        enable = true;
        desktopEnvironment = "gnome";
      };

      # TODO: Set this
      networking.primaryInterface = "eno1";

      # audio.enable = true;
    };
  };
}
