{ lib, inputs, ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  ${lib.ns} = {
    core = {
      users.priviledgedUser = false;
      home-manager.enable = true;
      nix.autoUpgrade = true;

      device = {
        type = "desktop";
        address = "192.168.88.244";
        memory = 1024 * 16;

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
    };

    hardware = {
      secure-boot.enable = true;
      scanner.enable = true;

      file-system = {
        type = "zfs";
        tmpfsTmp = true;
        zfs.trim = true;
        zfs.encryption.passphraseCred = inputs.nix-resources.secrets.zfsPassphrases.msi;
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    system = {
      audio.enable = true;
      ssh.server.enable = true;
      networking.wiredInterface = "enp3s0";

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
      scrutiny.collector.enable = true;

      backups.restic = {
        enable = true;
        schedule = "*-*-* 14:00:00";
        runMaintenance = false;
      };
    };
  };
}
