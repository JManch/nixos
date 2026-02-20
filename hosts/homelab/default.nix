{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib) ns foldl';
  inherit (lib.${ns}) hostIps;
  inherit (config.${ns}.services) wireguard;
  inherit (inputs.nix-resources.secrets) fqDomain tomFqDomain;
  trustedHostIps =
    foldl' (a: e: a ++ (map (ip: "${ip}/32") (hostIps e)))
      [ ]
      [ "ncase-m1" "framework" ];
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  ${ns} = {
    core = {
      home-manager.enable = true;

      device = {
        type = "server";
        cpu.type = "amd";
        cpu.threads = 4;
        memory = 1024 * 8;
        gpu.type = null;
        address = "192.168.89.2";
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
        mediaDir = "/media";
      };
    };

    profiles = {
      music.enable = true;
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
      mealie.enable = true;
      acme.enable = true;
      taskchampion-server.enable = true;
      air-vpn.confinement.enable = true;
      atuin-server.enable = true;
      anki-sync-server.enable = true;
      arr-stack.enable = true;
      qbittorrent-nox.enable = true;
      unrealircd.enable = true;

      silverbullet = {
        enable = true;
        allowedAddresses = trustedHostIps ++ [
          "10.20.20.33/32" # pixel 9
          "192.168.100.2/32" # pixel 9 VPN
        ];
      };

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
        ];

        virtualHosts = {
          squaremap = {
            extraAllowedAddresses = with wireguard.friends; [ "${address}/${toString subnet}" ];
            extraConfig = ''
              reverse_proxy http://127.0.0.1:25566
              handle_errors {
                respond "Minecraft server is hibernating or offline" 503
              }
            '';
          };
        };
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
        allowedAddresses =
          trustedHostIps
          ++ [
            "10.20.20.33/32" # pixel 9
            "192.168.100.2/32" # pixel 9 VPN
          ]
          ++ (with wireguard.friends; [ "${address}/${toString subnet}" ]);
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

      filebrowser = {
        enable = true;
        storeInRam = true;
        allowedAddresses = trustedHostIps ++ (with wireguard.friends; [ "${address}/${toString subnet}" ]);
      };

      minecraft-server = {
        enable = true;
        package = pkgs.papermcServers.papermc-1_21_11;
        interfaces = [ "wg-friends" ];

        plugins = with pkgs.${ns}.minecraft-plugins; [
          vivecraft
          squaremap
          aura-skills
          levelled-mobs
          tab-tps
          luck-perms
          gsit
          play-times
        ];

        files = {
          "spigot.yml".value = # yaml
            ''
              world-settings:
                default:
                  entity-tracking-range:
                    players: 128
                    animals: 64
                    monsters: 64
                  merge-radius:
                    exp: 0
                    item: 0
            '';

          "plugins/AuraSkills/config.yml".value = # yaml
            ''
              on_death:
                reset_xp: true
            '';

          "plugins/Vivecraft-Spigot-Extensions/config.yml".value = # yaml
            ''
              bow:
                standingmultiplier: 1
                seatedheadshotmultiplier: 2
              welcomemsg:
                enabled: true
                welcomeVanilla: '&player has joined with non-VR!'
              crawling:
                enabled: true
              teleport:
                enable: false
            '';

          "plugins/squaremap/config.yml".value = # yaml
            ''
              settings:
                web-address: https://squaremap.${fqDomain}
                internal-webserver:
                  bind: 127.0.0.1
                  port: 25566
            '';

          "plugins/LevelledMobs/rules.yml" = {
            reference = "${pkgs.${ns}.minecraft-plugins.levelled-mobs}/config/rules.yml";
            diff = ''
              --- rules.yml	2026-02-06 21:57:37.533978751 +0000
              +++ rules-custom.yml	2026-02-06 21:56:43.769471945 +0000
              @@ -283,9 +283,9 @@
               default-rule:
                 use-preset:
                   #===== Choose a Challenge =====
              -    #- challenge-vanilla
              +    - challenge-vanilla
                   #- challenge-bronze
              -    - challenge-silver
              +    #- challenge-silver
                   #- challenge-gold
                   #- challenge-platinum
                   #- challenge-formula
              @@ -301,10 +301,10 @@
                   - lvlmodifier-custom-formula
               
                   #===== Choose Additional Options =====
              -    - nametag-using-numbers
              +    #- nametag-using-numbers
                   #- nametag-using-indicator
                   #- nametag-minimized
              -    #- nametag-disabled
              +    - nametag-disabled
                   #- custom-death-messages
               
               
            '';
          };
        };
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

      beammp-server = {
        enable = false;
        autoStart = false;
        openFirewall = true;
        interfaces = [ "wg-friends" ];
      };

      audiobookshelf = {
        enable = true;
        extraAllowedAddresses = with wireguard.friends; [ "${address}/${toString subnet}" ];
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      desktop.enable = false;

      backups = {
        rclone = {
          enable = true;

          timerConfig = {
            OnCalendar = "*-*-* 13:00:00";
            Persistent = true;
          };
        };

        restic = {
          enable = true;

          timerConfig = {
            OnCalendar = "*-*-* 05:00:00";
            Persistent = true;
          };

          server = {
            enable = true;
            remoteCopySchedule = "*-*-* 05:30:00";
            remoteMaintenanceSchedule = "Sun *-*-* 06:00:00";
          };
        };
      };

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
