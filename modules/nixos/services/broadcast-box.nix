{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    optional
    genAttrs
    optionalString
    getExe'
    ;
  inherit (config.${ns}.services) caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) broadcastBoxDiscordVars;
in
{
  opts = with lib; {
    autoStart = mkEnableOption "Broadcast Box service auto start";
    proxy = mkEnableOption ''
      publically exposing Broadcast Box with a reverse proxy.
    '';

    allowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of address to give access to Broadcast Box.
      '';
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for Broadcast Box to be exposed on.
      '';
    };

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

  asserts = [
    (cfg.proxy -> caddy.enable)
    "Broadcast box proxy mode requires caddy to be enabled"
  ];

  nixpkgs.overlays = [
    (_: _: {
      inherit (inputs.nixpkgs-broadcast-box.legacyPackages.${pkgs.system}) broadcast-box;
    })
  ];

  services.broadcast-box = {
    enable = true;
    package = inputs.broadcast-box.packages.${pkgs.system}.default;
    openFirewall = true;
    web = {
      inherit (cfg) port;
      host = optionalString cfg.proxy "127.0.0.1";
      openFirewall = true;
    };
    settings = {
      UDP_MUX_PORT = cfg.udpMuxPort;
      DISABLE_STATUS = false;
      STREAM_HOST_URL = "https://stream.${fqDomain}/"; # for discord fork
    };
  };

  # User is just for accessing the secret
  users.users.broadcast-box = {
    isSystemUser = true;
    group = "broadcast-box";
  };
  users.groups.broadcast-box = { };

  systemd.services.broadcast-box = {
    serviceConfig.User = "broadcast-box";
    serviceConfig.EnvironmentFile = broadcastBoxDiscordVars.path;
    wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
  };

  # Playback for remote clients sometimes breaks until service is restarted
  systemd.services.broadcast-box-restart = {
    description = "Broadcast Box Restarter";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${getExe' pkgs.systemd "systemctl"} restart broadcast-box";
    startAt = "*-*-* 04:00:00";
  };

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedTCPPorts = optional (!cfg.proxy) cfg.port;
    allowedUDPPorts = [ cfg.udpMuxPort ];
  });

  networking.firewall.allowedUDPPorts = [ cfg.udpMuxPort ];

  ns.services.caddy.virtualHosts.stream = mkIf cfg.proxy {
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };
}
