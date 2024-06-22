{ lib
, pkgs
, config
, osConfig
, ...
} @ args:
let
  inherit (lib) mkIf utils mkOption mkPackageOption getExe length types literalExpression;

  terminalSubmodule = {
    options = {
      exePath = mkOption {
        type = types.str;
        default = null;
        example = literalExpression "${lib.getExe config.programs.alacritty.package}";
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
      default = {
        exePath = getExe config.programs.alacritty.package;
        class = "Alacritty";
      };
      description = "Information about the default terminal";
    };

    style = {
      font = {
        family = mkOption {
          type = types.str;
          default = "BerkeleyMono Nerd Font";
          description = "Font family name";
          example = "Fira Code";
        };

        package = mkOption {
          type = types.package;
          default = (utils.flakePkgs args "nix-resources").berkeley-mono-nerdfont;
          description = "Font package";
          example = literalExpression "pkgs.fira-code";
        };
      };

      cursor = {
        package = mkPackageOption pkgs "bibata-cursors" { };

        name = mkOption {
          type = types.str;
          description = "Cursor name";
          default = "Bibata-Modern-Classic";
        };

        size = mkOption {
          type = types.int;
          default = 24;
          description = "Cursor size in pixels";
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
    };
  };

  config =
    let
      cfg = config.modules.desktop;
      osDesktop = osConfig.modules.system.desktop;
    in
    {
      assertions = mkIf (cfg.windowManager != null) (utils.asserts [
        osDesktop.enable
        "You cannot select a window manager if usrEnv desktop is not enabled"
        (osDesktop.desktopEnvironment == null)
        "You cannot use a desktop environment with a window manager"
        (length osConfig.device.monitors != 0)
        "Device monitors must be configured to use a window manager"
      ]);
    };
}
