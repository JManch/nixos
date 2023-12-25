{
  lib,
  config,
  ...
}: let
  inherit (lib) types mkOption;
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
        example = 1920;
      };
      height = mkOption {
        type = types.int;
        example = 1080;
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
  options = {
    monitors = mkOption {
      type = types.listOf (types.submodule monitorSubmodule);
      default = [];
    };
    primaryMonitor = mkOption {
      type = types.submodule monitorSubmodule;
    };
  };
  config = {
    primaryMonitor = lib.lists.findFirst (m: m.primary == true) null config.monitors;
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
