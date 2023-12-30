{
  imports = [
    ./hardware-configuration.nix
  ];

  device = {
    type = "vm";
    cpu = "vm-amd";
    gpu = null;
    monitors = [ ];
  };

  usrEnv = {
    homeManager.enable = true;
    desktop = {
      enable = true;
    };
  };

  modules = {
    hardware = {
      fileSystem = {
        trim = false;
        rootTmpfsSize = "1G";
      };
    };

    system = {
      ssh.enable = false;
      networking = {
        tcpOptimisations = true;
        firewall.enable = false;
        resolved.enable = true;
      };
      impermanence = {
        zsh = true;
        starship = true;
        neovim = true;
        lazygit = true;
      };
    };
  };

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.defaultSession = "xfce";
  };

  networking.hostId = "8d4ed64c";

  system.stateVersion = "23.05";
}
