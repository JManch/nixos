{ lib
, pkgs
, inputs
, ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.services = {

    dunst = {
      enable = mkEnableOption "Dunst";
      monitorNumber = mkOption {
        type = types.int;
        default = 1;
        description = "The monitor number to display notifications on";
      };
    };

    wallpaper = {
      default = mkOption {
        type = types.package;
        default = inputs.nix-resources.packages.${pkgs.system}.wallpapers.rx7;
        description = ''
          The default wallpaper to use if randomise is false.
        '';
      };
      randomise = mkEnableOption "random wallpaper selection";
      randomiseFrequency = mkOption {
        type = types.str;
        default = "weekly";
        description = ''
          How often to randomly select a new wallpaper. Format is for the systemd timer OnCalendar option.
        '';
        example = "monthly";
      };
      setWallpaperCmd = mkOption {
        type = types.nullOr types.str;
        default = "";
        description = ''
          Command for setting the wallpaper. Must accept the wallpaper image path appended as an argument.
        '';
      };
    };

  };
}
