{ lib
, config
, ...
}:
with lib; let
  monitorSubmodule = {
    options = {
      name = mkOption {
        type = types.str;
        example = "DP-1";
      };
      number = mkOption {
        type = types.int;
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
        type = types.float;
        default = 60;
      };
      position = mkOption {
        type = types.str;
        example = "0x0";
        description = "Relative position of the monitor from the top left corner.";
      };
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      workspaces = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "Workspaces to put on the monitor.";
      };
    };
  };
in
{
  imports = [
    ./wayland
  ];
  options.desktop = {
    compositor = mkOption {
      type = with types; nullOr (enum [ ]);
      description = ''
        The desktop compositor to use.
      '';
    };
    monitors = mkOption {
      type = types.listOf (types.submodule monitorSubmodule);
      default = [ ];
    };
    cursorSize = mkOption {
      type = types.int;
      default = 24;
    };
  };
  config =
    let
      monitors = config.desktop.monitors;
    in
    {
      assertions = [
        {
          assertion =
            ((lib.length monitors) != 0)
            -> ((lib.length (lib.filter (m: m.number == 1) monitors)) == 1);
          message = "Exactly one monitor must be set to primary (number 1).";
        }
        {
          assertion = allUnique (map (m: m.number) monitors);
          message = "Monitor numbers must be unique.";
        }
        # {
        #   assertion = lib.lists.all (x: y: x + 1 == y) (lib.lists.sort (map (m: m.number) monitors));
        #   message = "Monitor numbers must be sequential.";
        # }
      ];
    };
}
