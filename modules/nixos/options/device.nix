{ lib
, config
, ...
}:
let
  inherit (lib) mkOption types;
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
        description = "Relative position of the monitor from the top left corner";
      };
      enabled = mkOption {
        type = types.bool;
        default = true;
      };
      workspaces = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "Workspaces to put on the monitor";
      };
    };
  };
in
{
  options.device = {
    type = mkOption {
      type = with types; nullOr (enum [ "laptop" "desktop" "server" "vm" ]);
      description = "The type/purpose of the device";
    };

    cpu = mkOption {
      type = with types; nullOr (enum [ "intel" "vm-intel" "amd" "vm-amd" ]);
      description = "The device's CPU manufacturer";
    };

    gpu = mkOption {
      type = with types; nullOr (enum [ "nvidia" "amd" ]);
      description = "The device's GPU manufacturer";
    };

    monitors = mkOption {
      type = types.listOf (types.submodule monitorSubmodule);
      default = [ ];
    };
  };

  config =
    let
      monitors = config.device.monitors;
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
          assertion = lib.allUnique (map (m: m.number) monitors);
          message = "Monitor numbers must be unique.";
        }
        # {
        #   assertion = lib.lists.all (x: y: x + 1 == y) (lib.lists.sort (map (m: m.number) monitors));
        #   message = "Monitor numbers must be sequential.";
        # }
      ];
    };
}
