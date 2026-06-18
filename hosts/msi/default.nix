{ lib, ... }:
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
        address = "192.168.88.239";
        memory = 1024 * 16;

        cpu = {
          name = "R5 2600";
          type = "amd";
          threads = 12;
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
      secure-boot.enable = false;
      scanner.enable = true;

      file-system = {
        type = "ext4";
        tmpfsTmp = true;
        ext4.trim = true;
        swap.enable = true;
        swap.size = 1024 * 20; # swap needed for overwatch shader caching using massive amounts of memory
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
      lact = {
        enable = true;
        acknowledgeUserIssue = true;
      };
      scrutiny.collector.enable = true;
    };

    system = {
      audio.enable = true;
      ssh.server.enable = true;

      windows = {
        enable = true;
        bootEntry = {
          enable = true;
          fsAlias = "HD1d65535a2";
        };
      };

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
        desktopEnvironment = "gnome";
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
