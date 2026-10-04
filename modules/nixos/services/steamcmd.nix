{
  lib,
  cfg,
  pkgs,
  utils,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    mapAttrs'
    nameValuePair
    getExe
    getExe'
    optionals
    ;
in
{
  enableOpt = false;
  conditions = [ (cfg.apps != { }) ];

  opts."apps" = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, ... }: {
          options = {
            id = mkOption {
              type = types.ints.positive;
              description = "Steam app ID to install";
            };

            branch = mkOption {
              type = types.str;
              default = "public";
              description = "Branch to install";
            };

            betapass = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Password for the beta branch";
            };

            dir = mkOption {
              type = types.str;
              readOnly = true;
              default = "/var/lib/steamcmd/apps/${name}";
              description = "Install directory.";
            };

            unit = mkOption {
              type = types.str;
              readOnly = true;
              default = "steamcmd-${name}.service";
              description = "Update unit, for use in a game service's wants/after";
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Attribute set of steam apps to install. Each app will create a unit that
      installs and updates.

      # In game service add:
      wants = [ ''${config.steamcmd.apps.''${appName}.unit ]; (wants so that game still attempts start if update fails)
      after = [ ''${config.steamcmd.apps.''${appName}.unit ];
    '';
  };

  users.groups."steamcmd" = { };
  users.users."steamcmd" = {
    isSystemUser = true;
    group = "steamcmd";
  };

  systemd.services = mapAttrs' (
    name: app:
    nameValuePair "steamcmd-${name}" {
      description = "Install or update Steam app ${name} (${toString app.id})";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = lib.${lib.ns}.hardeningBaseline config {
        Type = "oneshot";
        User = "steamcmd";
        Group = "steamcmd";
        Environment = "HOME=/var/lib/steamcmd"; # steamcmd boostraps into $HOME/.local/share/Steam
        StateDirectory = "steamcmd";
        StateDirectoryMode = "0711";
        SyslogIdentifier = "steamcmd-${name}";

        ExecStart = utils.escapeSystemdExecArgs (
          [
            (getExe' pkgs.util-linux "flock")
            "/var/lib/steamcmd/.lock" # only run one steamcmd install at a time
            (getExe pkgs.steamcmd)
            "+force_install_dir"
            app.dir
            "+login"
            "anonymous"
            "+app_update"
            (toString app.id)
            "-beta"
            app.branch
          ]
          ++ optionals (app.betapass != null) [
            "-betapassword"
            app.betapass
          ]
          ++ [ "+quit" ]
        );

        TimeoutStartSec = 3600; # allow time for updates
        DynamicUser = false;
        MemoryDenyWriteExecute = false;
        ProtectProc = "default";
        ProcSubset = "all";
        RestrictNamespaces = "user mnt"; # for steam-run's bubblewrap
        SystemCallArchitectures = "native x86"; # steamcmd is 32-bit
        SystemCallFilter = [ ]; # bubblewrap needs all syscalls
        UMask = "0022";
      };
    }
  ) cfg.apps;

  # Example for game that needs steamworks sdk:
  # systemd.services."mygame" = {
  #   preStart = ''
  #     mkdir -p "$HOME/.steam/sdk64"
  #     ln -sfn /var/lib/steamcmd/apps/1007/linux64/steamclient.so "$HOME/.steam/sdk64/steamclient.so"
  #   '';
  # };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/steamcmd";
    user = "steamcmd";
    group = "steamcmd";
    mode = "0711";
  };
}
