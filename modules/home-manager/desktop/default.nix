{ lib
, pkgs
, config
, inputs
, nixosConfig
, ...
}:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    ./wayland
    ./common
    ./font.nix
  ];

  options.modules.desktop = {

    windowManager = mkOption {
      type = with types; nullOr (enum [ "hyprland" ]);
      default = null;
      description = "The window manager to use";
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

  config = lib.mkIf nixosConfig.usrEnv.desktop.enable {

    assertions =
      let
        windowManager = config.modules.desktop.windowManager;
        nixosDesktop = nixosConfig.usrEnv.desktop;
      in
      [
        {
          assertion = (windowManager != null) -> (nixosDesktop.enable);
          message = "You cannot select a window manager if usrEnv desktop is not enabled";
        }
        {
          assertion = (windowManager != null) -> (lib.length nixosConfig.device.monitors != 0);
          message = "Device monitors must be configured to use the ${windowManager} window manager";
        }
        {
          assertion =
            (windowManager == "hyprland" || windowManager == "sway")
            -> (nixosDesktop.desktopEnvironment == null);
          message = "Cannot use a desktop environment with window manager ${windowManager}";
        }
      ];

    # Many applications need this for xdg-open url opening however package
    # managers rarely include is as a dependency for some reason
    home.packages = [ pkgs.xdg-utils ];

    # TODO: Verify that every desktopEnvironment/windowManager really wants this enabled (I doubt it)
    xdg.portal.enable = true;
  };
}
