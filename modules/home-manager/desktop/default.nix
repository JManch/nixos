{ lib
, config
, osConfig
, ...
}:
let
  inherit (lib) mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop = {

    windowManager = mkOption {
      type = with types; nullOr (enum [ "hyprland" ]);
      default = null;
      description = "The window manager to use";
    };
    terminal = mkOption {
      type = with types; nullOr types.str;
      default = null;
      description = "Path to the default terminal executable";
    };
    style = {
      font = {
        family = mkOption {
          type = types.str;
          default = null;
          description = "Font family name";
          example = "Fira Code";
        };
        package = mkOption {
          type = types.package;
          default = null;
          description = "Font package";
          example = "pkgs.fira-code";
        };
      };
      cornerRadius = mkOption {
        type = types.int;
        default = 10;
        description = "The corner radius to use for all curve styled applications";
      };
      borderWidth = mkOption {
        type = types.int;
        default = 2;
        description = "Border width in pixels for all desktop applications";
      };
      gapSize = mkOption {
        type = types.int;
        default = 10;
        description = "Gap size in pixels for all desktop applications";
      };
      cursorSize = mkOption {
        type = types.int;
        default = 24;
      };
    };
    util = {
      enableShaders = mkOption {
        type = types.str;
        default = "";
        description = "Command to enable screen shaders";
      };
      disableShaders = mkOption {
        type = types.str;
        default = "";
        description = "Command to disable screen shaders";
      };
    };
  };

  config = lib.mkIf osConfig.usrEnv.desktop.enable {

    assertions =
      let
        windowManager = config.modules.desktop.windowManager;
        terminal = config.modules.desktop.terminal;
        nixosDesktop = osConfig.usrEnv.desktop;
      in
      [
        {
          assertion = (windowManager != null) -> nixosDesktop.enable;
          message = "You cannot select a window manager if usrEnv desktop is not enabled";
        }
        {
          assertion = (windowManager != null) -> (lib.length osConfig.device.monitors != 0);
          message = "Device monitors must be configured to use the ${windowManager} window manager";
        }
        {
          assertion =
            (windowManager == "hyprland" || windowManager == "sway")
            -> (nixosDesktop.desktopEnvironment == null);
          message = "Cannot use a desktop environment with window manager ${windowManager}";
        }
        {
          assertion = nixosDesktop.enable -> (terminal != null);
          message = "`config.modules.desktop.terminal` must be declared if desktop environment is enabled";
        }
      ];
  };
}
