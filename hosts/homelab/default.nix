{
  ns,
  self,
  config,
  inputs,
  ...
}:
let
  inherit (config.${ns}.services) wireguard;
  ncaseM1IPAddress = self.nixosConfigurations.ncase-m1.config.${ns}.device.ipAddress;
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  ${ns} = {
    core.homeManager.enable = true;

    device = {
      type = "server";
      cpu.type = "amd";
      cpu.cores = 4;
      memory = 1024 * 8;
      gpu.type = null;
      ipAddress = "192.168.89.2";
      vpnNamespace = "air-vpn";
    };

    hardware = {
      secureBoot.enable = true;
      graphics.hardwareAcceleration = true;
      printing.server.enable = true;

      fileSystem = {
        type = "zfs";
        extendedLoaderTimeout = true;
        zfs.trim = true;
        zfs.encryption.passphraseCred = inputs.nix-resources.secrets.zfsPassphrases.homelab;
      };

      coral = {
        enable = true;
        type = "pci";
      };
    };

    services = {
      hass.enable = true;
      unifi.enable = true;
      mosquitto.enable = true;
      mikrotik-backup.enable = true;
      index-checker.enable = false;
      fail2ban.enable = true;
      mealie.enable = false;
      acme.enable = true;
      taskchampion-server.enable = true;
      air-vpn.confinement.enable = true;

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
        trustedAddresses = [
          "192.168.89.2/32"
          "192.168.88.0/24"
          "192.168.100.0/24"
          "10.20.20.0/24"
          "10.0.0.2/32" # NCASE-M1 on friends VPN
        ];
        extraFail2banTrustedAddresses = [ "10.0.0.0/24" ];
        goAccessExcludeIPRanges = [
          "192.168.89.2"
          "192.168.88.0-192.168.88.255"
        ];
      };

      torrent-stack = {
        enable = true;
        mediaDir = "/media";
      };

      dns-stack = {
        enable = true;
        routerAddress = "192.168.88.1";
        enableIPv6 = false;
      };

      frigate = {
        enable = true;
        webrtc.enable = true;
        nvrAddress = "192.168.40.6";
      };

      broadcast-box = {
        enable = true;
        port = 8081;
        autoStart = true;
        proxy = true;
        interfaces = [ "wg-friends" ];
        allowedAddresses = [
          "${ncaseM1IPAddress}/32"
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
        routerPeer = true;
        routerAllowedIPs = [ "10.0.0.0/24" ];
        address = "10.0.0.7";
        listenPort = 51820;
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
          "${ncaseM1IPAddress}/32"
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
        jellyseerr.enable = true;

        # Google TV on guest VLAN
        reverseProxy.extraAllowedAddresses = with wireguard.friends; [
          "10.30.30.6/32"
          "${address}/${toString subnet}"
        ];
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
