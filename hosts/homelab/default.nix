{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  networking.hostId = "8d4ed64c";

  device = {
    type = "server";
    cpu.type = "amd";
    cpu.cores = 4;
    memory = 8000;
    gpu.type = null;
    ipAddress = "192.168.89.2";
  };

  usrEnv = {
    homeManager.enable = true;
    desktop.enable = false;
  };

  modules = {
    hardware = {
      fileSystem.trim = true;
      fileSystem.extendedLoaderTimeout = true;
      graphics.hardwareAcceleration = true;
      printing.server.enable = true;
    };

    services = {
      hass.enable = true;
      unifi.enable = true;
      mosquitto.enable = true;
      qbittorrent-nox.enable = true;
      mikrotik-backup.enable = true;
      index-checker.enable = true;

      calibre = {
        enable = true;
        extraAllowedAddresses = [
          # Kobo on guest network
          "10.30.30.16/32"
        ];
      };

      vaultwarden = {
        enable = true;
        adminInterface = false;
      };

      caddy = {
        enable = true;
        interfaces = [ "wg-friends" ];
        lanAddressRanges = [
          "192.168.89.2/32"
          "192.168.88.0/24"
          "192.168.100.0/24"
          "10.20.20.0/24"
          "10.0.0.2/32" # NCASE-M1 on friends VPN
        ];
        goAccessExcludeIPRanges = [
          "192.168.89.2"
          "192.168.88.0-192.168.88.255"
        ];
      };

      dns-server-stack = {
        enable = true;
        routerAddress = "192.168.88.1";
        enableIPv6 = false;
      };

      frigate = {
        enable = true;
        # Disabling in an attempt to workaround https://github.com/AlexxIT/go2rtc/issues/716
        # TODO: Update: this is likely fixed by go2rtc 1.9.2 but there are new
        # webrtc options and I need to go through them
        webrtc.enable = false;
        nvrAddress = "192.168.40.6";
      };

      broadcast-box = {
        enable = true;
        port = 8081;
        autoStart = true;
        proxy = true;
        interfaces = [ "wg-friends" ];
      };

      zigbee2mqtt = {
        enable = true;
        deviceNode = "/dev/ttyACM0";
      };

      wireguard.friends = {
        enable = true;
        autoStart = true;
        routerPeer = true;
        routerAllowedIPs = [ "10.0.0.0/24" ];
        address = "10.0.0.7";
        subnet = 24;
        dns = {
          host = true;
          port = 13233;
        };
      };

      scrutiny = {
        server.enable = true;
        collector.enable = true;
      };

      wgnord = {
        enable = true;
        setDNS = false;
        splitTunnel = true;
      };

      nfs.server = {
        enable = false;
        supportedMachines = [ "ncase-m1.lan" ];
      };

      fail2ban = {
        enable = true;
        ignoredIPs = [
          "192.168.89.2/32"
          "192.168.88.0/24"
          "192.168.100.0/24"
          "10.20.20.0/24"
          "10.0.0.0/24"
        ];
      };

      restic = {
        enable = true;
        backupSchedule = "*-*-* 05:00:00";
        server = {
          enable = true;
          remoteCopySchedule = "*-*-* 05:30:00";
          remoteMaintenanceSchedule = "Sun *-*-* 06:00:00";
        };
      };

      minecraft-server = {
        enable = true;
        memory = 2000;
        interfaces = [ "wg-friends" ];
        plugins = [
          "vivecraft"
          "squaremap"
          "aura-skills"
          "levelled-mobs"
          "tab-tps"
          "luck-perms"
          "gsit"
          "play-times"
        ];
      };

      jellyfin = {
        enable = true;
        openFirewall = false;
        autoStart = true;
        reverseProxy.enable = true;
        mediaDirs = {
          shows = "/var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin/shows";
          movies = "/var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin/movies";
        };
      };

      beammp-server = {
        enable = true;
        autoStart = false;
        openFirewall = true;
        interfaces = [ "wg-friends" ];
      };
    };

    system = {
      networking = {
        primaryInterface = "enp1s0";
        staticIPAddress = "192.168.89.2/24";
        defaultGateway = "192.168.89.1";
        firewall.enable = true;
        tcpOptimisations = true;
      };
    };
  };
}
