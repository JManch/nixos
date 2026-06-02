{
  lib,
  cfg,
  pkgs,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    mkOption
    mkEnableOption
    mkPackageOption
    types
    literalExpression
    ;
in
{
  enableOpt = false;

  opts = {
    font = {
      family = mkOption {
        type = types.str;
        default = "BerkeleyMono Nerd Font";
        description = "Font family name";
        example = "Fira Code";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.${ns}.berkeley-mono-nerd-font;
        description = "Font package";
        example = literalExpression "pkgs.fira-code";
      };
    };

    cursor = {
      enable = mkEnableOption "custom cursor theme" // {
        default = osConfig.${ns}.system.desktop.desktopEnvironment == null;
      };

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

  home.pointerCursor = mkIf cfg.cursor.enable {
    gtk.enable = true; # always want this enabled for gtk apps
    name = cfg.cursor.name;
    package = cfg.cursor.package;
    size = cfg.cursor.size;
  };
}
