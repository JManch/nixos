{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    singleton
    genAttrs
    ;
  steamcmd = getExe pkgs.steamPackages.steamcmd;
  steam-run = getExe pkgs.steam-run;
  dataDir = "/var/lib/satisfactory-server";
in
{
  opts = with lib; {
    openFirewall = mkEnableOption "opening the firewall on default interfaces";
    autoStart = mkEnableOption "automatic server start";

    port = mkOption {
      type = types.port;
      default = 7777;
      description = "Port for the Satisfactory server to listen on";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for the Satisfactory server to be
        exposed on
      '';
    };
  };

  networking.firewall = {
    allowedUDPPorts = mkIf cfg.openFirewall [ cfg.port ];
    allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
    interfaces = genAttrs cfg.interfaces (_: {
      allowedUDPPorts = [ cfg.port ];
      allowedTCPPorts = [ cfg.port ];
    });
  };

  systemd.services.satisfactory-server = {
    description = "Satisfactory Dedicated Server";
    wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = lib.${ns}.hardeningBaseline config {
      DynamicUser = true;
      ExecStartPre = "${steamcmd} +force_install_dir ${dataDir} +login anonymous +app_update 1690800 validate +quit";
      ExecStart = "${steam-run} ${dataDir}/FactoryServer.sh";
      StateDirectory = "satisfactory-server";
      StateDirectoryMode = "0750";

      ProtectProc = "default";
      ProcSubset = "all";
      RestrictNamespaces = false;
      SystemCallArchitectures = [ ];
      SystemCallFilter = [ ];
      MemoryDenyWriteExecute = false;
    };
  };

  ns.backups.satisfactory = {
    backend = "restic";
    paths = [ "/var/lib/private/satisfactory-server/.config/Epic/FactoryGame/Saved/SaveGames" ];
    restore.pathOwnership."/var/lib/private/satisfactory-server" = {
      user = "nobody";
      group = "nogroup";
    };
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/satisfactory-server";
    user = "nobody";
    group = "nogroup";
    mode = "0750";
  };
}
