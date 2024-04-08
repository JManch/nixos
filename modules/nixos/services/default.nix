{ lib, config, username, ... }:
let
  inherit (lib) mkEnableOption mkOption types concatStringsSep;
in
{
  imports = lib.utils.scanPaths ./.;

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
            description = "Assigned IP address for this device on the VPN";
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
  };
}
