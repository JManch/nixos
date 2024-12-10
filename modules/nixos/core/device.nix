{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    findFirst
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;

  monitorSubmodule = {
    options = {
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If the monitor should be disabled by default and enabled on-demand
          set this to false
        '';
      };

      name = mkOption {
        type = types.str;
        example = "DP-1";
      };

      number = mkOption { type = types.int; };

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
        default = config.${ns}.device.primaryMonitor.refreshRate;
        description = ''
          Higher refresh rate to use during gaming and any other scenario where
          smoothness is preferred. Only affects the primary monitor.
        '';
      };

      gamma = mkOption {
        type = types.float;
        default = 1.0;
        example = 0.75;
        description = "Custom gamma level";
      };

      position = {
        x = mkOption {
          type = types.int;
          default = 0;
          description = "Relative x position of monitor from top left corner";
        };
        y = mkOption {
          type = types.int;
          default = 0;
          description = "Relative y position of monitor from top left corner";
        };
      };

      transform = mkOption {
        type = types.int;
        default = 0;
        description = "Rotation transform according to Hyprlands transform list";
      };

      mirror = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name of other display to mirror";
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
  options.${ns}.device = {
    type = mkOption {
      type = types.enum [
        "laptop"
        "desktop"
        "server"
        "vm"
      ];
      description = "The type/purpose of the device";
    };

    cpu = {
      type = mkOption {
        type = types.enum [
          "intel"
          "amd"
        ];
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
        type =
          with types;
          nullOr (enum [
            "nvidia"
            "amd"
          ]);
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

    primaryMonitor = mkOption {
      type = types.submodule monitorSubmodule;
      readOnly = true;
      default =
        findFirst (m: m.number == 1)
          (throw "Attempted to access primary monitors but monitors have not been configured")
          config.${ns}.device.monitors;
    };

    ipAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        The local IP address of the device on my home network. Must be a static
        address.
      '';
    };

    hassIntegration = {
      enable = mkEnableOption "Home Assistant Integration";
      endpoint = mkOption {
        type = types.str;
        default = "https://home.${fqDomain}";
        description = ''
          Endpoint of the home assistance instance. Should always be accessible
          on this device.
        '';
      };
    };

    vpnNamespace = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The default confinement VPN namespace to use";
    };
  };

  config =
    let
      inherit (lib)
        sort
        zipListsWith
        init
        mapAttrsToList
        tail
        head
        all
        ;
      inherit (config.${ns}.device) monitors vpnNamespace;
    in
    {
      assertions = lib.${ns}.asserts [
        (
          let
            sorted = sort (a: b: a < b) (map (m: m.number) monitors);
            diff = zipListsWith (a: b: b - a) (init sorted) (tail sorted);
          in
          (monitors == [ ]) || ((all (a: a == 1) diff) && ((head sorted) == 1))
        )
        "Monitor numbers must be sequential and start from 1"
        (
          (vpnNamespace == null)
          -> (all (x: x == false) (mapAttrsToList (_: v: v.vpnConfinement.enable) config.systemd.services))
        )
        "Services on this host have VPN confinement enabled but no VPN namespace is set"
        ((vpnNamespace != null) -> (config.vpnNamespaces.${vpnNamespace}.enable or false))
        "The VPN namespace '${vpnNamespace}' is not enabled or does not exist"
      ];
    };
}
