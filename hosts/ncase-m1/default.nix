{ ns, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  ${ns} = {
    device = {
      type = "desktop";
      ipAddress = "192.168.88.254";
      memory = 1024 * 64;
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

    core = {
      homeManager.enable = true;
      builder = true;
    };

    hardware = {
      secureBoot.enable = true;
      vr.enable = true;
      fanatec.enable = true;

      fileSystem = {
        type = "zfs";
        zfs.trim = true;
        # Use unstable for now to avoid going all the way back to kernel 6.6
        # https://github.com/NixOS/nixpkgs/commit/f8a1ba0e7db0dee3eec1258f31b25d004e461204
        # Waiting on https://github.com/openzfs/zfs/pull/16472
        zfs.unstable = true;
        zfs.encryption.passphraseCred = "DHzAexF2RZGcSwvqCLwg/iAAAAABAAAADAAAABAAAABgFSFxxQ/0+azOxSEAAAAAgAAAAAAAAAALACMA8AAAACAAAAAAngAgfVDpsadj61Q6zefRbnRE7cvhHc1DpI7gMNKDXMKOOKIAEDlzP5LzG88yjmWHsJXE/EZ4qqjp3mzdnsYjQ82ro32k9AsMs7Tv8Uai9qgtc2vVYESqyVxLe2+mEBzyWBTxiJCDvqHUjJTHGzyA0gaDFhJViuPCCSo5T7iXgtUFZr52pC3U0fxTKkVm5Ya57cF/v7IFy1ag8NkuYBmzAE4ACAALAAAEEgAgS8Wltz3CoDBZ7R9XBd9Gs2m2N4Un83GJoQgIMu29yZIAEAAgDgR0f0bQLZDpQ9a2LAQA2PW6vjhxcdIkn88i9CEEhEVLxaW3PcKgMFntH1cF30azabY3hSfzcYmhCAgy7b3JkgAAAACUTpVoNuSuS15mZTCPiWRnI1koRkx6rlaq8HxWLtlHYbLtm55PnfMXp+Ol1NzsrEL+8gL0s1krIOe23toa4vM/pPGQvLk9qjD00alv7Tb02etK7Vl6UpeQSPRhXy+7hfjG9x++GFtz+7ZnoTNgwqpc6WNOHTmK1X6B2MrcIZQiWY2vZ4AL6NhHXVTzwFgwdd0f+7n1Jr0hLQ==";
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
      mosquitto.explorer.enable = true;

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
        autoStart = false;
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

      satisfactory-server = {
        enable = false;
        autoStart = false;
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
        wiredInterface = "eno1";
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

  programs.ryzen-monitor-ng.enable = true;
}
