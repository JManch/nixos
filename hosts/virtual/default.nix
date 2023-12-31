{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "vm";
    cpu = "vm-amd";
    gpu = null;
    monitors = [
      {
        name = "UNKNOWN";
        number = 1;
        refreshRate = 59.951;
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
      compositor = "hyprland";
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
      greetd = {
        enable = false;
        launchCmd = "Hyprland";
      };
    };

    system = {
      ssh.enable = true;
      networking = {
        tcpOptimisations = true;
        firewall.enable = false;
        resolved.enable = true;
      };
      impermanence = {
        zsh = true;
        firefox = true;
        starship = true;
        neovim = true;
        lazygit = true;
        swww = true;
      };
    };
  };

  networking.hostId = "8d4ed64c";

  system.stateVersion = "23.05";
}
