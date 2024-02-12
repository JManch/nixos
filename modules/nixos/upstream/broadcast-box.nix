{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.services.broadcast-box;
in
{
  config = mkIf cfg.enable {

    systemd.services.broadcast-box = {
      description = "Broadcast Box";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = lib.lists.optional cfg.autoStart "multi-user.target";

      environment =
        let
          inherit (builtins) toString;
          inherit (lib) concatStringsSep boolToString;
        in
        {
          REACT_APP_API_PATH = "/api";
          HTTP_ADDRESS = "${cfg.httpServerAddress}:${toString cfg.tcpPort}";
          UDP_MUX_PORT = mkIf (cfg.udpMuxPort != null) "${toString cfg.udpMuxPort}";
          NETWORK_TEST_ON_START = boolToString cfg.networkTestOnStart;
          STUN_SERVERS = concatStringsSep "|" cfg.stunServers;
          ENABLE_HTTP_REDIRECT = mkIf cfg.enableHttpRedirect "yes";
          SSL_CERT = cfg.sslCert;
          SSL_KEY = cfg.sslKey;
          NAT_1_TO_1_IP = cfg.nat1To1Ip;
          INCLUDE_PUBLIC_IP_IN_NAT_1_TO_1_IP = mkIf cfg.includePublicIpInNat1To1Ip "yes";
        } // cfg.extraEnv;

      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${cfg.package}/bin/broadcast-box-unwrapped";
        WorkingDirectory = "${cfg.package}/share";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.tcpPort ];
      allowedUDPPorts = lib.optional (cfg.udpMuxPort != null) cfg.udpMuxPort;
    };

  };

  options.services.broadcast-box = {

    enable = mkEnableOption "broadcast box";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      defaultText = pkgs.literalExpression "pkgs.broadcast-box";
      description = lib.mdDoc ''
        Broadcast box package to use.
      '';
    };

    tcpPort = mkOption {
      type = types.int;
      default = 8080;
      description = lib.mdDoc ''
        The port for the web server to listen on.
      '';
    };

    udpMuxPort = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = lib.mdDoc ''
        The UDP port to serve all WebRTC traffic over. If `null`, a random UDP
        port will be used. The `openFirewall` option will *not* open the random
        port.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Open the ports specified in `webPort` and `udpMuxPort`.
      '';
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = lib.mkDoc ''
        Whether Broadcast Box should be started automatically.
      '';
    };

    networkTestOnStart = mkOption {
      type = types.bool;
      default = false;
      description = lib.mkDoc ''
        Whether to run a network test on start. Broadcast Box will exit if the
        test fails.
      '';
    };

    stunServers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = lib.mkDoc ''
        List of STUN servers. Useful if Broadcast Box is running behind a NAT.
      '';
    };

    httpServerAddress = mkOption {
      type = types.str;
      default = "";
      description = lib.mkDoc ''
        The HTTP server address.
      '';
    };

    enableHttpRedirect = mkOption {
      type = types.bool;
      default = false;
      description = lib.mkDoc ''
        Whether HTTP traffic should be redirected to HTTPS.
      '';
    };

    sslCert = mkOption {
      type = types.str;
      default = "";
      description = lib.mkDoc ''
        Path to the SSL certification for Broadcast Box's HTTP server.
      '';
    };

    sslKey = mkOption {
      type = types.str;
      default = "";
      description = lib.mkDoc ''
        Path to the SSL key for Broadcast Box's HTTP server.
      '';
    };

    nat1To1Ip = mkOption {
      type = types.str;
      default = "";
      description = lib.mkDoc ''
        If behind a NAT use this to auto insert your public IP.
      '';
    };

    includePublicIpInNat1To1Ip = mkOption {
      type = types.bool;
      default = false;
      description = lib.mkDoc ''
        Like `nat1To1Ip` but autoconfigured.
      '';
    };

    extraEnv = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = lib.mdDoc ''
        Extra environment variables for Broadcast Box.
      '';
    };

  };
}
