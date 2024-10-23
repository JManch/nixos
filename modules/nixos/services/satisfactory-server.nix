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
    getExe
    singleton
    genAttrs
    ;
  cfg = config.${ns}.services.satisfactory-server;
  steamcmd = getExe pkgs.steamPackages.steamcmd;
  steam-run = getExe pkgs.steam-run;
  dataDir = "/var/lib/satisfactory-server";
in
mkIf cfg.enable {
  users.users.satisfactory = {
    isSystemUser = true;
    home = dataDir;
    createHome = true;
    group = "satisfactory";
  };
  users.groups.satisfactory = { };

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
      User = "satisfactory";
      Group = "satisfactory";
      DynamicUser = false;
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

  backups.satisfactory = {
    paths = [ "/var/lib/satisfactory-server/.config/Epic/FactoryGame/Saved/SaveGames" ];
    restore.pathOwnership = {
      "/var/lib/satisfactory-server/.config/Epic/FactoryGame/Saved/SaveGames" = {
        user = "satisfactory";
        group = "satisfactory";
      };
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/satisfactory-server";
    user = "satisfactory";
    group = "satisfactory";
    mode = "0750";
  };
}
