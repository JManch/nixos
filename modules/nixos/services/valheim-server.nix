{
  lib,
  cfg,
  pkgs,
  utils,
  config,
  hostname,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    genAttrs
    singleton
    toSentenceCase
    ;
  port = 2456;
  steamCmdApp = config.${ns}.services.steamcmd.apps."valheim-server";
in
{
  opts = with lib; {
    openFirewall = mkEnableOption "opening the firewall on default interfaces";
    autoStart = mkEnableOption "automatic server start";

    interfaces = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of additional interfaces for the Valheim server to be exposed on.
      '';
    };
  };

  ns.services.steamcmd.apps."valheim-server" = {
    id = 896660;
  };

  systemd.services."valheim-server" = {
    wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
    after = [
      "network.target"
      steamCmdApp.unit
    ];
    wants = [ steamCmdApp.unit ];
    serviceConfig = lib.${ns}.hardeningBaseline config {
      StateDirectory = "valheim-server";
      SyslogIdentifier = "valheim-server";
      WorkingDirectory = "/var/lib/valheim-server";
      KillSignal = "SIGINT";

      # From Valheim's start_server.sh script
      Environment = [
        "LD_LIBRARY_PATH=${steamCmdApp.dir}/linux64"
        "SteamAppId=892970"
        "HOME=/var/lib/valheim-server"
      ];

      ExecStart = utils.escapeSystemdExecArgs [
        (getExe pkgs.steam-run)
        "${steamCmdApp.dir}/valheim_server.x86_64"
        "-name"
        (toSentenceCase hostname)
        "-port"
        (toString port)
        "-world"
        "Dedicated"
        "-savedir"
        "/var/lib/valheim-server"
        "-public"
        "0"
      ];

      MemoryDenyWriteExecute = false;
      ProtectProc = "default";
      ProcSubset = "all";
      RestrictNamespaces = "user mnt"; # for steam-run's bubblewrap
      SystemCallArchitectures = "native x86"; # steamcmd is 32-bit
      SystemCallFilter = [ ]; # bubblewrap needs all syscalls
    };
  };

  networking.firewall = {
    allowedUDPPorts = mkIf cfg.openFirewall [
      port
      (port + 1)
    ];

    interfaces = genAttrs cfg.interfaces (_: {
      allowedUDPPorts = [
        port
        (port + 1)
      ];
    });
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/valheim-server";
    user = "nobody";
    group = "nogroup";
    mode = "0750";
  };
}
