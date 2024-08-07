{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  device = {
    type = "desktop";
    ipAddress = "192.168.88.254";
    memory = 1024 * 32;
    hassIntegration.enable = true;

    cpu = {
      name = "R7 3700x";
      type = "amd";
      cores = 16;
    };

    gpu = {
      name = "RX 7900XT";
      type = "amd";
      hwmonId = 2;
    };

    monitors = [
      {
        name = "DP-1";
        number = 1;
        refreshRate = 144.0;
        gamingRefreshRate = 165.0;
        gamma = 0.75;
        width = 2560;
        height = 1440;
        position.x = 2560;
        position.y = 0;
        workspaces = builtins.genList (i: (i * 2) + 1) 25;
      }
      {
        name = "HDMI-A-1";
        number = 2;
        refreshRate = 59.951;
        width = 2560;
        height = 1440;
        position.x = 0;
        position.y = 0;
        workspaces = builtins.genList (i: (i * 2) + 2) 25;
      }
      {
        # Enabled on-demand for sim racing
        enabled = false;
        name = "DP-2";
        mirror = "DP-1";
        number = 3;
        refreshRate = 59.951;
        width = 2560;
        height = 1440;
        position.x = -2560;
        position.y = 0;
        transform = 2;
      }
    ];
  };

  modules = {
    core.homeManager.enable = true;

    hardware = {
      secureBoot.enable = true;
      vr.enable = true;
      fanatec.enable = true;

      fileSystem = {
        type = "zfs";
        zfs.trim = true;
        zfs.encryption.passphraseCred = ''
          DHzAexF2RZGcSwvqCLwg/iAAAAABAAAADAAAABAAAACC7x/VG/f0sAMQRX0AAAAAgAAAA \
          AAAAAALACMA8AAAACAAAAAAngAgFD/ouh3hJ2deKa9kL7wsQR8vpJjQF2B8ZeVi0qq+HF \
          MAEL+ELOC9b+zMAXhtTemqTYjjzkxajL6W5vBnH0itpdMsdNiz1Ygi2Y1LJ3WOAAxMUJy \
          i5fqwCs6zfMZf/PyWFp+BvwlLnmjUxE8HnpdP84V+Mk2yqdr8GynOPkKTCDsAAi4bGt9A \
          2ZuEaWsIdKE8Mxk1EstoZxCO6v6PAE4ACAALAAAAEgAg4w/rD608CdGmVrgpix1PuZrHS \
          98cp0+5EE5gROfkEEYAEAAge8wRM/plZ2+RlyuK9ildKgjNmWXOEnBUZZ3ZGZH2YmHjD+ \
          sPrTwJ0aZWuCmLHU+5msdL3xynT7kQTmBE5+QQRgAAAAAIOn2j5mI7lQGIjKcSwOvOmRi \
          f+oeb49Convojrvp7+E0nhJmuVkWn0AWp0zzmV9U1te8L2sKha/Cv361IVDq6FjjT6ctr \
          rknsLUgwOdjVdG3ndl7gXB6LcEMQpem1nB/VZAQqLASE+CU/SWHZsHHcaicJyYkoJLe3F \
          qqXoP2+xGUVNAgOaFYIZcQs856a2o52cxDDkDyq3A==
        '';
      };

      printing.client = {
        enable = true;
        serverAddress = "homelab.lan";
      };
    };

    programs = {
      wine.enable = true;
      winbox.enable = true;
      matlab.enable = true;
      wireshark.enable = true;
      adb.enable = true;

      gaming = {
        enable = true;
        steam.enable = true;
        gamescope.enable = true;
        gamemode.enable = true;
      };
    };

    services = {
      udisks.enable = true;
      greetd.enable = true;
      lact.enable = true;
      scrutiny.collector.enable = true;

      restic = {
        enable = true;
        backupSchedule = "*-*-* 15:00:00";
      };

      wgnord = {
        enable = true;
        excludeSubnets = [ "192.168.89.2/32" ];
      };

      wireguard.friends = {
        enable = true;
        routerPeer = true;
        routerAllowedIPs = [ "10.0.0.0/24" ];
        address = "10.0.0.2";
        subnet = 24;
        dns = {
          enable = false;
          address = "10.0.0.7";
        };
      };

      nfs.client = {
        enable = false;
        supportedMachines = [ "homelab.lan" ];
      };

      ollama = {
        enable = false;
        interfaces = [ "wg-friends" ];
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      windows.enable = true;
      bluetooth.enable = true;
      virtualisation.libvirt.enable = true;

      desktop = {
        enable = true;
        desktopEnvironment = null;
      };

      networking = {
        primaryInterface = "eno1";
        defaultGateway = "192.168.88.1";
        tcpOptimisations = true;
        resolved.enable = true;
        firewall.enable = true;

        wireless = {
          enable = true;
          interface = "wlp6s0";
          disableOnBoot = true;
        };
      };

      audio = {
        enable = true;
        extraAudioTools = true;
      };
    };
  };
}
