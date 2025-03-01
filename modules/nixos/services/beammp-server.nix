{
  lib,
  cfg,
  pkgs,
  config,
  selfPkgs,
  hostname,
}:
let
  inherit (lib)
    ns
    mkIf
    genAttrs
    optional
    singleton
    toUpper
    getExe
    ;
  configFile = pkgs.writers.writeTOML "ServerConfig.toml" settings;
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
{
  opts = with lib; {
    openFirewall = mkEnableOption "opening the firewall";

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable BeamMP Server autostart";
    };

    port = mkOption {
      type = types.port;
      default = 30814;
      description = "Port for the BeamMP Server to listen on";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for BeamMP Server to be exposed on.
      '';
    };
  };

  users.users.beammp = {
    group = "beammp";
    isSystemUser = true;
  };
  users.groups.beammp = { };

  systemd.services.beammp-server = {
    description = "BeamMP Server";
    after = [ "network.target" ];
    startLimitBurst = 3;
    startLimitIntervalSec = 30;
    wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];

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

  ns.persistence.directories = singleton {
    directory = "/var/lib/beammp-server";
    user = "beammp";
    group = "beammp";
    mode = "0755";
  };
}
