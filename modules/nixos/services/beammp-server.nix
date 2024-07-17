{
  lib,
  pkgs',
  config,
  hostname,
  ...
}:
let
  inherit (lib)
    mkIf
    genAttrs
    optional
    singleton
    ;
  cfg = config.modules.services.beammp-server;
in
mkIf cfg.enable {
  services.beammp-server = {
    enable = true;
    autoStart = cfg.autoStart;
    package = pkgs'.beammp-server;
    authenticationKeyFile = config.age.secrets.beammpAuthKey.path;
    settings = {
      General = {
        ResourceFolder = "Resources";
        Map = "/levels/${cfg.map}/info.json";
        MaxPlayers = 5;
        Tags = "Freeroam";
        Port = cfg.port;
        Private = true;
        Debug = false;
        Name = "${lib.toUpper hostname} BeamMP Server";
        Description = "Hosted on NixOS";
        LogChat = true;
        MaxCars = 10;
      };

      Misc = {
        SendErrorsShowMessage = true;
        SendErrors = true;
        ImScaredOfUpdates = false;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = optional cfg.openFirewall cfg.port;
    allowedUDPPorts = optional cfg.openFirewall cfg.port;
    interfaces = (
      genAttrs cfg.interfaces (_: {
        allowedTCPPorts = [ cfg.port ];
        allowedUDPPorts = [ cfg.port ];
      })
    );
  };

  persistence.directories = singleton {
    directory = "/var/lib/beammp-server";
    user = "beammp";
    group = "beammp";
    mode = "755";
  };
}
