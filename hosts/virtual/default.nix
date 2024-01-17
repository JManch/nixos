{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "vm";
    cpu.type = "vm-amd";
    gpu.type = null;
    monitors = [
      {
        name = "Virtual-1";
        number = 1;
        refreshRate = 60.0;
        width = 1920;
        height = 1080;
        position = "0x0";
        workspaces = [ 1 2 3 4 5 6 7 8 9 ];
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
