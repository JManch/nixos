{
  lib,
  config,
  ...
}:
with lib; let
  monitorSubmodule = {
    options = {
      name = mkOption {
        type = types.str;
        example = "DP-1";
      };
      primary = mkOption {
        type = types.bool;
        default = false;
      };
      width = mkOption {
        type = types.int;
        example = 2560;
      };
      height = mkOption {
        type = types.int;
        example = 1440;
      };
      refreshRate = mkOption {
        type = types.int;
        default = 60;
      };
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      workspaces = mkOption {
        type = types.listOf types.str;
        default = null;
      };
    };
  };
in {
  options.desktop = {
    enable = mkEnableOption "desktop environment";
    compositor = mkOption {
      type = with types; nullOr (enum []);
      description = ''
        The desktop compositor to use.
      '';
    };
    monitors = mkOption {
      type = types.listOf (types.submodule monitorSubmodule);
      default = [];
    };
  };
  config = {
    assertions = [
      {
        assertion =
          ((lib.length config.monitors) != 0)
          -> ((lib.length (lib.filter (m: m.primary) config.monitors)) == 1);
        message = "Exactly one monitor must be set to primary.";
      }
    ];
  };
}
