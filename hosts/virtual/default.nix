{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "vm";
    cpu = "vm-amd";
    gpu = null;
  };

  usrEnv = {
    homeManager.enable = true;
    desktop = {
      enable = true;
      desktopManager = "xfce";
    };
  };

  modules = {
    hardware = {
      fileSystem = {
        trim = false;
        rootTmpfsSize = "1G";
        zpoolName = "zpool";
        bootLabel = "boot";
      };
    };

    services = {
      greetd.enable = false;
    };

    system = {
      networking = {
        tcpOptimisations = true;
        firewall.enable = false;
        resolved.enable = true;
      };
    };
  };

  networking.hostId = "8d4ed64c";

  system.stateVersion = "23.05";
}
