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
      gamingRefreshRate = mkOption {
        type = types.float;
        default = null;
        description = ''
          Gaming refresh rate to switch to when starting gamemode.
          Only affects the primary monitor.
        '';
      };
      position = mkOption {
        type = types.str;
        default = "0x0";
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

    cpu = {
      type = mkOption {
        type = with types; nullOr (enum [ "intel" "vm-intel" "amd" "vm-amd" ]);
        description = "The device's CPU manufacturer";
      };
      name = mkOption {
        type = types.str;
        default = "";
        description = "The CPU name, not critical";
      };
    };

    gpu = {
      type = mkOption {
        type = with types; nullOr (enum [ "nvidia" "amd" ]);
        default = null;
        description = "The device's GPU manufacturer";
      };
      name = mkOption {
        type = types.str;
        default = "";
        description = "The GPU name, not critical";
      };
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
      assertions = with lib; [
        {
          assertion =
            let
              sorted = lists.sort (a: b: a < b) (map (m: m.number) monitors);
              diff = lists.zipListsWith (a: b: b - a) (lists.init sorted) (lists.tail sorted);
            in
            (lists.all (a: a == 1) diff) && ((lists.head sorted) == 1);
          message = "Monitor numbers must be sequential and start from 1 (the primary monitor)";
        }
      ];
    };
}
