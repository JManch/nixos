{ lib, config, username, ... }:
let
  inherit (lib) mkEnableOption mkOption types concatStringsSep mkAliasOptionModule;
  cfg = config.modules.services;
in
{
  imports = lib.utils.scanPaths ./. ++ [
    (mkAliasOptionModule
      [ "backups" ]
      [ "modules" "services" "restic" "backups" ]
    )
  ];

  options.modules.services = {
    udisks.enable = mkEnableOption "udisks";
    lact.enable = mkEnableOption "Lact";

    wireguard =
      let
        wgInterfaceOptions = {
          enable = mkEnableOption "the wireguard interface";
          autoStart = mkEnableOption "auto start";
          routerPeer = mkEnableOption "my router as a peer";

          address = mkOption {
            type = types.str;
            default = null;
            example = "10.0.0.2/24";
            description = "Assigned IP address for this device on the VPN along with the subnet mask";
          };

          subnet = mkOption {
            type = types.int;
            default = null;
            example = "24";
            description = "Subnet of the wireguard network";
          };

          routerAllowedIPs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of allowed IPs for router peer";
          };

          peers = mkOption {
            type = types.listOf types.attrs;
            default = [ ];
            description = "Wireguard peers";
          };

          dns = {
            enable = mkEnableOption "a custom DNS server for the VPN";
            host = mkEnableOption "hosting the custom DNS server on this host";

            address = mkOption {
              type = types.str;
              default = null;
              description = "Address of the device hosting the DNS server inside the VPN";
            };

            port = mkOption {
              type = types.nullOr types.port;
              default = null;
              description = "Port for the DNS server to listen on";
            };
          };
        };
      in
      mkOption {
        default = { };
        type = with types; attrsOf (submodule { options = wgInterfaceOptions; });
        description = "Wireguard VPN interfaces";
      };

    greetd = {
      enable = mkEnableOption "Greetd with TUIgreet";

      sessionDirs = mkOption {
        type = types.listOf types.str;
        apply = concatStringsSep ":";
        default = [ ];
        description = "Directories that contain .desktop files to be used as session definitions";
      };
    };

    wgnord = {
      enable = mkEnableOption "Wireguard NordVPN";
      setDNS = mkEnableOption "setting DNS to Nord DNS" // {
        default = true;
      };

      splitTunnel = mkEnableOption ''
        only routing traffic from the wgnord interface. Useful for applications
        that support binding to interfaces (such as qBittorrent) where we only
        want that traffic routed through the VPN.

        Warning: with this setting enabled, traffic is only guarenteed to be
        routed through the VPN if the application binds to the interface.
      '';

      excludeSubnets = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of subnets to exclude from being routed through the VPN";
      };

      country = mkOption {
        type = types.str;
        default = "Switzerland";
        description = "The country to VPN to";
      };
    };

    jellyfin = {
      enable = mkEnableOption "Jellyfin";
      mediaPlayer = mkEnableOption "Jellyfin Media Player";
      openFirewall = mkEnableOption "opening the firewall";

      reverseProxy = {
        enable = mkEnableOption "Jellyfin Caddy virtual host";

        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "IP address that reverse proxy should point to";
        };
      };

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Jellyfin service auto start";
      };

      mediaDirs = mkOption {
        type = types.attrsOf types.str;
        default = { };

        example = {
          shows = "/home/${username}/videos/shows";
          movies = "/home/${username}/videos/movies";
        };

        description = ''
          Attribute set of media directories that will be bind mount to
          /var/lib/jellyfin/media. Key is the directory name in the bind
          location.
        '';
      };
    };

    ollama = {
      enable = mkEnableOption "Ollama";
      autoStart = mkEnableOption "Ollama service auto start";
    };

    broadcast-box = {
      enable = mkEnableOption "Broadcast Box";
      autoStart = mkEnableOption "Broadcast Box service auto start";
      proxy = mkEnableOption ''
        publically exposing Broadcast Box with a reverse proxy.
      '';

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Webserver listening port";
      };

      udpMuxPort = mkOption {
        type = types.port;
        default = 3000;
        description = "UDP port used for streaming";
      };
    };

    caddy = {
      enable = mkEnableOption "Caddy";

      lanAddressRanges = mkOption {
        type = types.listOf types.str;
        default = [ ];
        apply = v: concatStringsSep " " v;
        description = ''
          List of address ranges defining the local network. Endpoints marked
          as 'lan_only' will only accept connections from these ranges.
        '';
      };
    };

    dns-server-stack = {
      enable = mkEnableOption ''
        a DNS server stack using Ctrld and dnsmasq. Intended for use on server
        devices to provide DNS services on a network.
      '';
      enableIPv6 = mkEnableOption "IPv6 DNS responses";
      debug = mkEnableOption "verbose logs for debugging";

      listenPort = mkOption {
        type = types.port;
        default = 53;
        description = "Listen port for DNS requests";
      };

      ctrldListenPort = mkOption {
        type = types.port;
        default = 5354;
        description = "Listen port for the internal Ctrld DNS server";
      };

      routerAddress = mkOption {
        type = types.str;
        default = null;
        description = ''
          Local IP address of the router that internal DDNS queries should be
          pointed to.
        '';
      };

      dnsmasqConfig = mkOption {
        type = types.attrs;
        internal = true;
        readOnly = true;
        description = "Dnsmasq settings";
      };

      generateDnsmasqConfig = mkOption {
        type = types.functionTo (types.functionTo types.pathInStore);
        internal = true;
        readOnly = true;
        description = "Internal function for generate dnsmasq config from attrset";
      };
    };

    unifi = {
      enable = mkEnableOption "Unifi Controller";

      port = mkOption {
        type = types.port;
        internal = true;
        readOnly = true;
        default = 8443;
        description = ''
          Unifi Controller listen port. Cannot be changed declaratively.
        '';
      };
    };

    frigate = {
      enable = mkEnableOption "Frigate";

      port = mkOption {
        type = types.port;
        default = 5000;
      };

      rtspAddress = mkOption {
        type = types.functionTo types.str;
        default = _: "";
        description = ''
          Function accepting channel and subtype that returns the RTSP address string.
        '';
      };

      nvrAddress = mkOption {
        type = types.str;
        default = "";
        description = ''
          IP address of the NVR on the local network.
        '';
      };
    };

    mosquitto = {
      enable = mkEnableOption "Mosquitto MQTT Broker";

      users = mkOption {
        type = types.attrs;
        default = { };
        example = lib.literalExpression ''
          {
            frigate = {
              acl = [ "readwrite #" ];
              hashedPasswordFile = mqttFrigatePassword.path;
            };
          }
        '';
      };

      port = mkOption {
        type = types.port;
        default = 1883;
      };
    };

    hass = {
      enable = mkEnableOption "Home Assistant";

      enableInternal = mkOption {
        type = types.bool;
        default = false;
        internal = true;
      };

      port = mkOption {
        type = types.port;
        default = 8123;
      };
    };

    calibre = {
      enable = mkEnableOption "Calibre E-book Manager";

      port = mkOption {
        type = types.port;
        default = 8083;
      };
    };

    vaultwarden = {
      enable = mkEnableOption "Vaultwarden";
      adminInterface = mkEnableOption "admin interface. Keep disabled and enable when needed.";

      port = mkOption {
        type = types.port;
        default = 8222;
      };
    };

    zigbee2mqtt = {
      enable = mkEnableOption "Zigbee2MQTT";

      port = mkOption {
        type = types.port;
        default = 8084;
        description = "Port of the frontend web interface";
      };

      deviceNode = mkOption {
        type = types.str;
        example = "/dev/ttyUSB0";
        description = "The device node of the zigbee adapter.";
      };
    };

    scrutiny = {
      server.enable = mkEnableOption "hosting the Scrutiny web server";
      collector.enable = mkEnableOption ''
        the Scrutiny collector service. The collector service sends data to the
        web server and can run on any machine that can access the web server.
      '';

      port = mkOption {
        type = types.port;
        default = 8085;
        description = "Listen port of the web server";
      };
    };

    qbittorrent-nox = {
      enable = mkEnableOption "headless qBittorrent client";

      port = mkOption {
        type = types.port;
        default = 8087;
        description = "Listen port of the qBittorrent web GUI";
      };
    };

    nfs = {
      server = {
        enable = mkEnableOption "NFS server";

        supportedMachines = mkOption {
          type = types.listOf types.str;
          description = ''
            List of machines that this host can share NFS exports with.
          '';
        };

        fileSystems = mkOption {
          type = with types; listOf (submodule {
            options = {
              path = mkOption {
                type = types.str;
                example = "jellyfin";
                description = "Export path relative to /export";
              };

              clients = mkOption {
                type = types.attrsOf types.str;
                example = { "homelab.lan" = "ro,no_subtree_check"; };
                description = ''
                  Attribute set of client machine names associated with a comma
                  separated list of NFS export options
                '';
              };
            };
          });

          example = [{
            path = "/export";
            clients = {
              "homelab.lan" = "ro,no_subtree_check";
              "192.168.88.254" = "ro,no_subtree_check";
            };
          }];

          description = "List of local file systems that are exported by the NFS server";
        };
      };

      client = {
        enable = mkEnableOption "NFS client";

        supportedMachines = mkOption {
          type = types.listOf types.str;
          description = "List of machines this host can accept NFS file systems from";
        };

        fileSystems = mkOption {
          type = with types; listOf (submodule {
            options = {
              path = mkOption {
                type = types.str;
                example = "jellyfin";
                description = "Mount path relative to /mnt/nfs";
              };

              machine = mkOption {
                type = types.str;
                description = "NFS machine identifier according to exports(5)";
              };

              user = mkOption {
                type = types.str;
                description = "User owning the mounted directory";
              };

              group = mkOption {
                type = types.str;
                description = "Group owning the mounted directory";
              };

              options = mkOption {
                type = types.listOf types.str;
                default = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
                description = "List of options for the NFS file system";
              };
            };
          });

          example = [{
            name = "jellyfin";
            machine = "homelab.lan";
          }];

          description = "List of remote NFS file systems to mount";
        };
      };
    };

    wallabag = {
      enable = mkEnableOption "Wallabag";

      port = mkOption {
        type = types.port;
        default = 8088;
        description = "Port for the Wallabag server to listen on";
      };
    };

    fail2ban = {
      enable = mkEnableOption "Fail2ban";

      ignoredIPs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of address ranges to ignore";
      };
    };

    restic = {
      enable = mkEnableOption "Restic backups";

      backups = mkOption {
        type = types.attrs;
        default = { };
        description = ''
          Attribute set of Restic backups matching the upstream module backups
          options.
        '';
      };

      server = {
        enable = mkEnableOption "Restic REST server";

        dataDir = mkOption {
          type = types.str;
          description = "Directory where the restic repository is stored";
          default = "/var/backup/restic";
        };

        port = mkOption {
          type = types.port;
          default = 8090;
          description = "Port for the Restic server to listen on";
        };
      };
    };
  };

  config = {
    services.udisks2.enable = cfg.udisks.enable;

    # Allows user services like home-manager syncthing to start on boot and
    # keep running rather than stopping and starting with each ssh session on
    # servers
    users.users.${username}.linger = config.device.type == "server";
  };
}
