{ pkgs, username, ... }:
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

    monitors = [{
      name = "placeholder";
      number = 1;
      refreshRate = 60;
      width = 1920;
      height = 1080;
      position.x = 0;
      position.y = 0;
    }];
  };

  modules = {
    core = {
      homeManager.enable = false;
      autoUpgrade = true;
    };

    hardware = {
      fileSystem = {
        trim = true;
        tmpfsTmp = true;
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    system = {
      impermanence.enable = false;
      audio.enable = true;
      ssh.enable = true;
      networking.primaryInterface = "enp3s0";

      desktop = {
        enable = true;
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
      # restic = {
      #   enable = true;
      #   backupSchedule = "*-*-* 15:00:00";
      # };
    };
  };

  users.users.${username}.packages = with pkgs; [
    prismlauncher
    chromium
  ];
}
