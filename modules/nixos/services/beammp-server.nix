{
  ns,
  lib,
  pkgs,
  config,
  selfPkgs,
  hostname,
  ...
}:
let
  inherit (lib)
    mkIf
    genAttrs
    optional
    singleton
    toUpper
    getExe
    ;
  cfg = config.${ns}.services.beammp-server;
  configFile = (pkgs.formats.toml { }).generate "ServerConfig.toml" settings;
  authenticationKeyFile = config.age.secrets.beammpAuthKey.path;

  # The map can be changed by editing ServerConfig.toml. The chosen map will
  # persist between rebuilds.

  # List of vanilla maps:
  # gridmap_v2
  # johnson_valley
  # automation_test_track
  # east_coast_usa
  # hirochi_raceway
  # italy
  # jungle_rock_island
  # industrial
  # small_island
  # smallgrid
  # utah
  # west_coast_usa
  # driver_training
  # derbyV

  settings = {
    General = {
      ResourceFolder = "Resources";
      Map = "/levels/east_coast_usa/info.json";
      MaxPlayers = 5;
      Tags = "Freeroam";
      Port = cfg.port;
      Private = true;
      Debug = false;
      Name = "${toUpper hostname} BeamMP Server";
      Description = "Hosted on NixOS";
      LogChat = true;
      MaxCars = 10;
      # Auth key will be injected from secret in start-up script
      AuthKey = "";
    };

    Misc = {
      SendErrorsShowMessage = true;
      SendErrors = true;
      ImScaredOfUpdates = false;
    };
  };
in
mkIf cfg.enable {
  users.users.beammp = {
    group = "beammp";
    isSystemUser = true;
  };
  users.groups.beammp = { };

  systemd.services.beammp-server = {
    unitConfig = {
      Description = "BeamMP Server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitBurst = 3;
      StartLimitIntervalSec = 30;
    };

    serviceConfig = lib.${ns}.hardeningBaseline config {
      ExecStartPre = getExe (
        pkgs.writeShellApplication {
          name = "beammp-server-pre-start";
          runtimeInputs = with pkgs; [
            tomlq
            gnused
          ];
          text = ''
            conf="/var/lib/beammp-server/ServerConfig.toml"
            # Retain the map configured in the existing file to allow changing the
            # server's map without nix rebuilds
            if [ -f "$conf" ]; then
              map=$(tq --file "$conf" .General.Map | awk -F'/' '{print $3}')
            fi

            install -m600 ${configFile} "$conf"

            if [ -v map ]; then
              sed -i "s/^Map.*/Map = \"\/levels\/$map\/info.json\"/" "$conf"
            fi
            sed -i "s/^AuthKey.*/AuthKey = \"$(<${authenticationKeyFile})\"/" "$conf"
          '';
        }
      );
      ExecStart = "${getExe selfPkgs.beammp-server} --working-directory=/var/lib/beammp-server";
      StateDirectory = "beammp-server";
      DynamicUser = false;
      User = "beammp";
      Group = "beammp";

      SystemCallFilter = [
        "@system-service"
        "~@resources"
      ];
    };

    wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
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
    mode = "0755";
  };
}
