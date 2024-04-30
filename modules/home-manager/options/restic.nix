{ lib, username, ... }:
let
  inherit (lib) mkOption types mapAttrs' nameValuePair;
in
{
  options.backups = mkOption {
    type = types.attrsOf (types.submodule {
      freeformType = types.attrsOf types.anything;
      options = {
        paths = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };

        exclude = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };

        restore = {
          pathOwnership = mkOption {
            type = types.attrsOf (types.submodule {
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
            });
            default = { };
            description = ''
              Attribute for assigning ownership user and group for each
              backup path.
            '';
          };

          removeExisting = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to delete all files and directories in the backup paths
              before restoring backup.
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
    });
    default = { };
    apply = v: mapAttrs'
      (name: value: nameValuePair "home-${name}" (value // {
        paths = map (path: "/home/${username}/${path}") value.paths;
        exclude = map (path: "/home/${username}/${path}") value.exclude;
      }))
      v;
    description = ''
      Attribute set of Restic backups matching the upstream module backups
      options.
    '';
  };
}
