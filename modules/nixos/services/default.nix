{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.modules.services;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    udisks.enable = mkEnableOption "udisks";
    wireguard.enable = mkEnableOption "WireGuard";
    corectrl.enable = mkEnableOption "Corectrl";
    lact.enable = mkEnableOption "Lact";
    home-assistant.enable = mkEnableOption "Home Assistant";
    unifi.enable = mkEnableOption "Unifi Controller";
    calibre.enable = mkEnableOption "Calibre E-book Manager";

    greetd = {
      enable = mkEnableOption "Greetd with TUIgreet";

      sessionDirs = mkOption {
        type = types.listOf types.str;
        apply = builtins.concatStringsSep ":";
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

    frigate = {
      enable = mkEnableOption "Frigate";

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
  };

  config = {
    services.udisks2.enable = config.modules.services.udisks.enable;

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
    ];
  };
}
