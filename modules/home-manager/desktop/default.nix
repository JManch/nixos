{ lib, config, osConfig, ... }:
let
  inherit (lib) mkIf mkOption length types literalExpression;

  terminalSubmodule = {
    options = {
      exePath = mkOption {
        type = types.str;
        default = null;
        example = literalExpression "${config.programs.alacritty.package}/bin/alacritty";
      };

      class = mkOption {
        type = types.str;
        default = null;
        example = "Alacritty";
        description = "Window class of the terminal";
      };
    };
  };
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop = {
    windowManager = mkOption {
      type = types.nullOr (types.enum [ "Hyprland" ]);
      default = null;
      description = "Window manager to use";
    };

    terminal = mkOption {
      type = types.submodule terminalSubmodule;
      default = null;
      description = "Information about the default terminal";
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
          example = literalExpression "pkgs.fira-code";
        };
      };

      cornerRadius = mkOption {
        type = types.int;
        default = 10;
        description = "Corner radius to use for all styled applications";
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
        description = "Cursor size in pixels";
      };
    };
  };

  config =
    let
      cfg = config.modules.desktop;
      osDesktop = osConfig.usrEnv.desktop;
    in
    mkIf osDesktop.enable {
      assertions = [
        {
          assertion = (cfg.windowManager != null) -> osDesktop.enable;
          message = "You cannot select a window manager if usrEnv desktop is not enabled";
        }
        {
          assertion = (cfg.windowManager != null) -> (length osConfig.device.monitors != 0);
          message = "Device monitors must be configured to use the ${cfg.windowManager} window manager";
        }
        {
          assertion = (cfg.windowManager != null) -> (osDesktop.desktopEnvironment == null);
          message = "Cannot use a desktop environment with window manager ${cfg.windowManager}";
        }
      ];
    };
}
