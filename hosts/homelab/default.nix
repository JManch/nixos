{
  lib,
  config,
  inputs,
  selfPkgs,
  ...
}:
let
  inherit (lib) ns;
  inherit (lib.${ns}) hostIp;
  inherit (config.${ns}.services) wireguard;
  inherit (inputs.nix-resources.secrets) fqDomain tomFqDomain;
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  ${ns} = {
    adminPackages = [ selfPkgs.filen-cli ];

    core = {
      home-manager.enable = true;

      device = {
        type = "server";
        cpu.type = "amd";
        cpu.cores = 4;
        memory = 1024 * 8;
        gpu.type = null;
        ipAddress = "192.168.89.2";
        vpnNamespace = "air-vpn";
      };
    };

    hardware = {
      secure-boot.enable = true;
      graphics.hardwareAcceleration = true;
      printing.server.enable = true;

      file-system = {
        type = "zfs";
        extendedLoaderTimeout = true;
        zfs.trim = true;
        zfs.encryption.passphraseCred = inputs.nix-resources.secrets.zfsPassphrases.homelab;
      };
    };

    services = {
      home-assistant.enable = true;
      home-assistant.everythingPresenceContainer = false;
      postgresql.enable = true;
      unifi.enable = true;
      mosquitto.enable = true;
      mikrotik-backup.enable = true;
      index-checker.enable = false;
      fail2ban.enable = true;
      mealie.enable = false;
      acme.enable = true;
      taskchampion-server.enable = true;
      air-vpn.confinement.enable = true;
      atuin-server.enable = true;

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
        extraAllowedAddresses = [ "10.0.0.0/24" ];
      };

      caddy = {
        enable = true;
        interfaces = [ "wg-friends" ];
        trustedAddresses = [
          "192.168.89.2/32"
          "192.168.88.0/24"
          "192.168.100.0/24"
          "10.20.20.0/24"
          "10.0.0.2/32" # NCASE-M1 on friends VPN
          "${hostIp "surface-pro"}/32" # Surface pro on guest network cause no WPA3 support
        ];
        goAccessExcludeIPRanges = [
          "192.168.89.2"
          "192.168.88.0-192.168.88.255"
        ];
      };

      torrent-stack = {
        video.enable = true;
        music.enable = true;
        mediaDir = "/media";
      };

      dns-stack = {
        enable = true;
        routerAddress = "192.168.88.1";
        enableIPv6 = false;
      };

      frigate = {
        enable = true;
        coral.enable = true;
        coral.type = "pci";
        webrtc.enable = true;
        nvrAddress = "192.168.40.6";
      };

      broadcast-box = {
        enable = true;
        port = 8081;
        udpMuxPort = 3002;
        autoStart = true;
        proxy = true;
        interfaces = [ "wg-friends" ];
        allowedAddresses = [
          "${hostIp "ncase-m1"}/32"
          "${hostIp "surface-pro"}/32"
          "10.20.20.33/32" # pixel 9
          "10.20.20.11/32" # ncase-m1 wireless
        ] ++ (with wireguard.friends; [ "${address}/${toString subnet}" ]);
      };

      factorio-server = {
        enable = true;
        interfaces = [ "wg-friends" ];
      };

      zigbee2mqtt = {
        enable = true;
        proxy.enable = true;
        proxy.address = "127.0.0.1";
        mqtt.user = true;
        mqtt.tls = false;
        deviceNode = "/dev/ttyACM0";
      };

      wireguard.friends = {
        enable = true;
        autoStart = true;
        address = "10.0.0.7";
        listenPort = 51820;
        subnet = 24;

        peers = lib.singleton {
          publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
          presharedKeyFile = config.age.secrets.wg-friends-router-psk.path;
          allowedIPs = [ "10.0.0.0/24" ];
          endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString inputs.nix-resources.secrets.friendsWgRouterPort}";
        };

        dns = {
          host = true;
          domains = {
            ${fqDomain} = "10.0.0.7";
            ${tomFqDomain} = "10.0.0.9";
          };
          port = 13233;
        };
      };

      scrutiny = {
        server.enable = true;
        collector.enable = true;
      };

      nfs.server = {
        enable = false;
        supportedMachines = [ "ncase-m1.lan" ];
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

      file-server = {
        enable = true;
        allowedAddresses = [
          "${hostIp "ncase-m1"}/32"
          "${hostIp "surface-pro"}/32"
        ] ++ (with wireguard.friends; [ "${address}/${toString subnet}" ]);
      };

      minecraft-server = {
        enable = true;
        memory = 2000;
        interfaces = [ "wg-friends" ];
        extraAllowedAddresses = with wireguard.friends; [ "${address}/${toString subnet}" ];
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

        jellyseerr = {
          enable = true;
          extraAllowedAddresses = with wireguard.friends; [
            "${address}/${toString subnet}"
          ];
        };

        # Google TV on guest VLAN
        reverseProxy.extraAllowedAddresses = with wireguard.friends; [
          "10.30.30.6/32"
          "${address}/${toString subnet}"
        ];
      };

      navidrome = {
        enable = true;
        musicDir = "/media/music";
      };

      beammp-server = {
        enable = true;
        autoStart = false;
        openFirewall = true;
        interfaces = [ "wg-friends" ];
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      desktop.enable = false;

      networking = {
        wiredInterface = "enp0s16u1u4c2";
        staticIPAddress = "192.168.89.2/24";
        defaultGateway = "192.168.89.1";
        firewall.enable = true;
        tcpOptimisations = false;
      };
    };
  };
}
