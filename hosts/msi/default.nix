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
          threads = 8;
        };

        gpu = {
          name = "RTX 2070";
          type = "nvidia";
        };

        monitors = [
          {
            name = "placeholder";
            number = 1;
            refreshRate = 60.0;
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

    programs = {
      gaming = {
        enable = true;
        steam.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      scrutiny.collector.enable = true;
    };

    system = {
      audio.enable = true;
      ssh.server.enable = true;

      backups.restic = {
        enable = true;
        timerConfig = {
          OnCalendar = "*-*-* 14:00:00";
          Persistent = true;
        };
        runMaintenance = false;
      };

      desktop = {
        enable = true;
        # This wasn't stable in the past but testing it out now
        suspend.enable = true;
        desktopEnvironment = "plasma";
      };

      networking = {
        wiredInterface = "enp3s0";
        defaultGateway = "192.168.88.1";
        tcpOptimisations = true;
        resolved.enable = true;

        firewall = {
          enable = true;
          defaultInterfaces = [ "enp3s0" ];
        };
      };
    };
  };
}
