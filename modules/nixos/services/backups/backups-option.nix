lib: cfg:
let
  inherit (lib)
    mkOption
    types
    attrNames
    ;
in
mkOption {
  type = types.attrsOf (
    types.submodule (
      { name, config, ... }@args:
      {
        options = {
          backend = mkOption {
            type = types.enum (attrNames cfg.backends);
            description = "The backup backend to use";
          };

          paths = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths to backup";
          };

          backendOptions = mkOption {
            type =
              let
                backupConfig = config;
                backupName = name;
              in
              types.submodule (
                { config, ... }@args':
                cfg.backends.${args.config.backend} (args' // { inherit backupConfig backupName; })
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
            description = "Script to run after backing up";
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
