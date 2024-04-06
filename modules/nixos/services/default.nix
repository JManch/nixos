{ lib
, config
, username
, hostname
, ...
}:
let
  inherit (lib) mkEnableOption mkOption types concatStringsSep;
  cfg = config.modules.services;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    udisks.enable = mkEnableOption "udisks";
    lact.enable = mkEnableOption "Lact";

    wireguard = {
      friends = {
        enable = mkEnableOption ''
          private Wireguard server for use with friends. Requires a private key
          for the host to be stored in agenix.
        '';
        autoStart = mkEnableOption "auto start";

        address = mkOption {
          type = types.str;
          default = null;
          description = ''
            Assigned IP address for this device on the VPN.
          '';
        };
      };
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

      country = mkOption {
        type = types.str;
        default = "Switzerland";
        description = "The country to VPN to";
      };
    };

    jellyfin = {
      enable = mkEnableOption "Jellyfin";

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Jellyfin service auto start";
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
  };

  config = {
    services.udisks2.enable = config.modules.services.udisks.enable;

    # Allows user services like home-manager syncthing to start on boot and
    # keep running rather than stopping and starting with each ssh session on
    # servers
    users.users.${username}.linger = config.device.type == "server";

    assertions = [
      {
        assertion = cfg.greetd.enable -> (cfg.greetd.sessionDirs != [ ]);
        message = "Greetd session dirs must be set";
      }
      {
        assertion = cfg.caddy.enable -> (cfg.caddy.lanAddressRanges != [ ]);
        message = "LAN address ranges must be set for Caddy";
      }
      {
        assertion = cfg.dns-server-stack.enable -> (config.device.ipAddress != null);
        message = "The DNS server stack requires the device to have a static IP address set";
      }
      {
        assertion = cfg.dns-server-stack.enable -> (cfg.dns-server-stack.routerAddress != "");
        message = "The DNS server stack requires the device to have a router IP address set";
      }
      {
        assertion = cfg.frigate.enable -> (cfg.frigate.nvrAddress != "");
        message = "The Frigate service requires nvrAddress to be set";
      }
      {
        assertion = cfg.frigate.enable -> config.hardware.opengl.enable;
        message = ''
          The Frigate service requires hardware acceleration. Set
          `hardware.opengl.enable`.
        '';
      }
      {
        assertion = cfg.wireguard.friends.enable -> config.age.secrets."${hostname}FriendsWGKey" != null;
        message = "A secret key for the host must be configured to use the friends Wireguard VPN";
      }
    ];
  };
}
