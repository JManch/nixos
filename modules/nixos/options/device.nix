{ lib, config, ... }:
let
  inherit (lib) mkOption types;

  monitorSubmodule = {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
      };

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
        default = 60.0;
      };

      gamingRefreshRate = mkOption {
        type = types.float;
        default = (lib.fetchers.primaryMonitor config).refreshRate;
        description = ''
          Higher refresh to use during gaming and any other scenario where
          smoothness is preferred. Only affects the primary monitor.
        '';
      };

      gamma = mkOption {
        type = types.float;
        default = 1.0;
        example = 0.75;
        description = "Custom gamma level";
      };

      position = mkOption {
        type = types.str;
        default = "0x0";
        description = "Relative position of the monitor from the top left corner";
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
      type = types.enum [ "laptop" "desktop" "server" "vm" ];
      description = "The type/purpose of the device";
    };

    cpu = {
      type = mkOption {
        type = types.enum [ "intel" "amd" ];
        description = "The device's CPU manufacturer";
      };

      name = mkOption {
        type = types.str;
        default = "";
        description = "The CPU name, not critical";
      };

      cores = mkOption {
        type = types.int;
        description = "The CPU core count";
      };
    };

    memory = mkOption {
      type = types.int;
      description = "System memory in MB";
    };

    gpu = {
      type = mkOption {
        type = with types; nullOr (enum [ "nvidia" "amd" ]);
        default = null;
        description = ''
          The device's GPU manufacturer. Leave null if device does not have a
          dedicated GPU.
        '';
      };

      name = mkOption {
        type = types.str;
        default = "";
        description = "The GPU name, not critical";
      };

      hwmonId = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          The hwmon id of the GPU. Run `cat /sys/class/hwmon/*/name` to list
          devices. Id is position in list - 1.
        '';
      };
    };

    monitors = mkOption {
      type = types.listOf (types.submodule monitorSubmodule);
      default = [ ];
    };

    ipAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The local IP address of the device on my home network. Must be a static
        address.
      '';
    };
  };

  config =
    let
      inherit (lib) sort zipListsWith init tail head all;
      inherit (config.device) monitors;
    in
    {
      assertions = [
        {
          assertion =
            let
              sorted = sort (a: b: a < b) (map (m: m.number) monitors);
              diff = zipListsWith (a: b: b - a) (init sorted) (tail sorted);
            in
            (monitors == [ ]) || ((all (a: a == 1) diff) && ((head sorted) == 1));
          message = "Monitor numbers must be sequential and start from 1";
        }
      ];
    };
}
