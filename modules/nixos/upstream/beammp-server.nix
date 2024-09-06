{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkOption
    getExe
    ;
  cfg = config.services.beammp-server;
  settingsFormat = pkgs.formats.toml { };
  configFile = settingsFormat.generate "ServerConfig.toml" cfg.settings;
in
{
  options.services.beammp-server = {
    enable = lib.mkEnableOption "BeamMP Server";
    package = lib.mkPackageOption pkgs "beammp-server" { };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable BeamMP Server autostart";
    };

    settings = mkOption {
      type = settingsFormat.type;
      default = {
        Misc = {
          SendErrorsShowMessage = true;
          SendErrors = true;
          ImScaredOfUpdates = false;
        };
        General = {
          ResourceFolder = "Resources";
          Map = "/levels/gridmap_v2/info.json";
          MaxPlayers = 8;
          Description = "BeamMP Default Description";
          Tags = "Freeroam";
          Port = 30814;
          Private = true;
          Debug = false;
          Name = "BeamMP Server";
          LogChat = true;
          MaxCars = 1;
          AuthKey = "";
        };
      };
      apply =
        v:
        v
        // {
          General = v.General // {
            AuthKey = "";
          };
        };
      description = ''
        Settings for the BeamMP server. Do not include the auth key, it will
        automatically be added from the authentication key file.
      '';
    };

    authenticationKeyFile = mkOption {
      type = types.str;
      default = null;
      description = ''
        Path to file containing server authentication key
      '';
    };
  };

  config = mkIf cfg.enable {
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

      serviceConfig = {
        ExecStartPre = pkgs.writeShellScript "beammp-server-pre-start" ''
          install -m600 ${configFile} "/var/lib/beammp-server/ServerConfig.toml"
          ${getExe pkgs.gnused} -i "s/^AuthKey.*/AuthKey = \"$(<${cfg.authenticationKeyFile})\"/" "/var/lib/beammp-server/ServerConfig.toml"
        '';

        ExecStart = "${getExe cfg.package} --working-directory=/var/lib/beammp-server";
        StateDirectory = "beammp-server";

        User = "beammp";
        Group = "beammp";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateUsers = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectSystem = "strict"; # does not apply to service directories like StateDirectory
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectProc = "invisible";
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProcSubset = "pid";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@resources"
        ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        DeviceAllow = "";
        SocketBindDeny = config.${ns}.system.networking.publicPorts;
        MemoryDenyWriteExecute = true;
        UMask = "0077";
      };

      wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
    };
  };
}
