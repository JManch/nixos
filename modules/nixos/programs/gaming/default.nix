{ lib, ... }:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    ;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.programs.gaming = {
    enable = mkEnableOption "gaming optimisations";
    gamescope.enable = mkEnableOption "Gamescope";

    steam = {
      enable = mkEnableOption "Steam";
      lanTransfer = mkEnableOption "opening ports for LAN game transfer";
    };

    gamemode = {
      enable = mkEnableOption "Gamemode";

      wrappedPackage = mkOption {
        type = types.package;
        readOnly = true;
        description = "Wrapped gamemode package with profile functionality";
      };

      profiles = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              includeDefaultProfile = mkEnableOption "the default profile scripts in this profile";

              start = mkOption {
                type = types.lines;
                default = "";
              };

              stop = mkOption {
                type = types.lines;
                default = "";
              };
            };
          }
        );
        default = { };
        description = ''
          Attribute set of Gamemode profiles with start/stop bash scripts.
          Gamemode profiles can be enabled by setting the GAMEMODE_PROFILES
          environment variable to a comma separated list of profile names.
        '';
      };
    };
  };
}
