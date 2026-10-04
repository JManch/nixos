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
  port = 16261;
  directPort = 16262;
  steamCmdApp = config.${ns}.services.steamcmd.apps."project-zomboid-server";
in
{
  opts = with lib; {
    openFirewall = mkEnableOption "opening the firewall on default interfaces";
    autoStart = mkEnableOption "automatic server start";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of additional interfaces for the Project Zomboid to be
        exposed on
      '';
    };
  };

  ns.services.steamcmd.apps."project-zomboid-server" = {
    id = 380870;
    branch = "unstable";
    workshopId = 108600;
    workshopItems = [
      3386949627
      3389003300
      2710167561
      3809306528
      3619862853
    ];
  };

  systemd.sockets."project-zomboid-server" = {
    bindsTo = [ "project-zomboid-server.service" ];
    socketConfig = {
      ListenFIFO = "/run/project-zomboid-server/zomboid.control";
      RemoveOnStop = true;
      SocketGroup = "wheel";
      SocketMode = "0620";
    };
  };

  systemd.services."project-zomboid-server" = {
    wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
    requires = [ "project-zomboid-server.socket" ];
    after = [
      "network.target"
      "project-zomboid-server.socket"
      steamCmdApp.unit
    ];
    wants = [ steamCmdApp.unit ];
    serviceConfig = lib.${ns}.hardeningBaseline config {
      StateDirectory = "project-zomboid-server";
      SyslogIdentifier = "zomboid-server";

      StandardInput = "fd:project-zomboid-server.socket";
      StandardOutput = "journal";

      ExecStart = utils.escapeSystemdExecArgs [
        (getExe pkgs.steam-run)
        "${steamCmdApp.dir}/start-server.sh"
        "-cachedir=/var/lib/project-zomboid-server"
        "-servername"
        (toSentenceCase hostname)
        "-adminpassword"
        "admin"
        "-steamvac"
        "false"
      ];
      ExecStop = "+${pkgs.writeShellScript "project-zomboid-server-stop" ''
        [ -n "$MAINPID" ] || exit 0
        fifo=/run/project-zomboid-server/zomboid.control
        echo save > "$fifo"
        sleep 15
        echo quit > "$fifo"
        ${lib.getExe' pkgs.util-linux "waitpid"} "$MAINPID"
      ''}";

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
      directPort
    ];

    interfaces = genAttrs cfg.interfaces (_: {
      allowedUDPPorts = [
        port
        directPort
      ];
    });
  };

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/project-zomboid-server";
    user = "nobody";
    group = "nobody";
    mode = "0750";
  };
}
