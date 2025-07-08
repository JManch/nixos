args: cfg: isHome:
let
  inherit (args.lib)
    ns
    mkOption
    types
    mkEnableOption
    nameValuePair
    optionalString
    mapAttrs'
    attrNames
    ;
  impermanence = args.${if isHome then "osConfig" else "config"}.${ns}.system.impermanence;
in
mkOption {
  type = types.attrsOf (
    types.submodule (
      { name, config, ... }@args':
      {
        options = {
          isHome = mkOption {
            type = types.bool;
            internal = true;
            readOnly = true;
            default = isHome;
          };

          backend = mkOption {
            type = types.enum (attrNames cfg.backends);
            description = "The backup backend to use";
          };

          paths = mkOption {
            type = types.listOf types.str;
            default = [ ];
            apply =
              if args'.config.doNotModifyPaths then
                v: v
              else
                map (
                  path:
                  optionalString impermanence.enable "/persist"
                  + optionalString isHome "${args.config.home.homeDirectory}/"
                  + path
                );
            description = "Paths to backup";
          };

          doNotModifyPaths = mkOption {
            type = types.bool;
            default = false;
            description = ''
              By default, paths are prefixed with /persist if impermanence is enabled or with
              the user's home dir if the backup is defined in home-manager. Enable this
              option to false to disable this behaviour.
            '';
          };

          notifications = {
            failure = {
              enable = mkEnableOption "sending an email and discord notification when the backup fails" // {
                default = true;
              };

              config = mkOption {
                type = types.attrs;
                default = { };
                example = {
                  contentsRoot = "echo 'Custom contents'";
                };
                description = ''
                  Custom failure notify service config. Not merged with the default notify config.
                '';
              };
            };

            success = {
              enable = mkEnableOption "sending an email and discord notification when the backup succeeds";

              config = mkOption {
                type = types.attrs;
                default = { };
                description = ''
                  Custom success notify service config. Not merged with the default notify config.
                '';
              };
            };

            healthCheck = {
              enable = mkEnableOption "health check monitoring for this backup";

              var = mkOption {
                type = with types; nullOr str;
                default = null;
                description = ''
                  Optionally override the health check var.
                '';
              };
            };
          };

          timerConfig = mkOption {
            type = with types; nullOr attrs;
            default =
              if cfg.${config.backend} ? timerConfig then
                cfg.${config.backend}.timerConfig
              else
                {
                  OnCalendar = "daily";
                  Persistent = true;
                };
            example = {
              OnCalendar = "00:05";
              Persistent = true;
              RandomizedDelaySec = "5h";
            };
            description = ''
              When to run the backup. If set to null the backup will not automatically run.
            '';
          };

          backendOptions = mkOption {
            type =
              let
                backupConfig = config;
                backupName = name;
              in
              types.submodule (
                { config, ... }@args'':
                cfg.backends.${args'.config.backend} (args'' // { inherit backupConfig backupName; })
              );
            default = { };
            description = "Backend options";
          };

          preBackupScript = mkOption {
            type = types.lines;
            default = "";
            description = "Script to run before backing up";
          };

          postBackupScript = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Script to run after backing up. Runs even if the backup fails.
            '';
          };

          restore = {
            pathOwnership = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    user = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = ''
                        User to set restored files to. If null, user will not
                        be changed. Useful for modules that do not have static
                        IDs https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix.
                      '';
                    };

                    group = mkOption {
                      type = types.nullOr types.str;
                      default = null;
                      description = ''
                        Group to set restored files to. If null, group will not
                        be changed.
                      '';
                    };
                  };
                }
              );
              default = { };
              apply =
                if !isHome && !args'.config.doNotModifyPaths then
                  mapAttrs' (name: value: nameValuePair (optionalString impermanence.enable "/persist" + name) value)
                else
                  value: value;
              description = ''
                Attribute for assigning ownership user and group for each
                backup path.
              '';
            };

            removeExisting = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether to delete all files and directories in the backup
                paths before restoring backup.
              '';
            };

            preRestoreScript = mkOption {
              type = types.lines;
              default = "";
              description = "Script to run before restoring the backup";
            };

            postRestoreScript = mkOption {
              type = types.lines;
              default = "";
              description = "Script to run after restoring the backup";
            };
          };
        };
      }
    )
  );
  default = { };
}
