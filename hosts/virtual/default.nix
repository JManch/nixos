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
    desktop.enable = false;
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
      };
    };
  };

  networking.hostId = "8d4ed64c";

  system.stateVersion = "23.05";
}
