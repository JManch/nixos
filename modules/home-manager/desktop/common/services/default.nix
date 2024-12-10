{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    mkAliasOptionModule
    ;
in
{
  imports = lib.${ns}.scanPaths ./. ++ [
    (mkAliasOptionModule
      [ "darkman" ]
      [
        ns
        "desktop"
        "services"
        "darkman"
      ]
    )
  ];

  options.${ns}.desktop.services = {
    darkman = {
      enable = mkEnableOption "Darkman";

      switchMethod = mkOption {
        type = types.enum [
          "manual"
          "coordinates"
          "hass"
        ];
        default = "coordinates";
        description = ''
          Manual means the theme will not switch automatically. Coordinates
          uses the configured longitude and latitude to switch at sunrise and
          sunset. Hass uses a home assistant brightness entity to select the
          theme.
        '';
      };

      hassEntity = mkOption {
        type = types.str;
        description = ''
          Hass binary_sensor entity to determine dark mode toggle
        '';
      };

      switchScripts = mkOption {
        type = types.attrsOf (types.functionTo types.lines);
        default = { };
        description = ''
          Attribute set of functions that accept a string "dark" or "light"
          and provide a script for making the theme switch.
        '';
      };

      switchApps = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              paths = mkOption {
                type = with types; listOf str;
                default = [ ];
                example = [
                  "waybar/config"
                  "waybar/style.css"
                ];
                description = ''
                  List of paths relative to $HOME that point to files managed
                  by home-manager that contain hex colors we want to switch
                '';
              };

              format = mkOption {
                type = with types; functionTo str;
                default = c: c;
                example = c: "#${c}";
                description = ''
                  Function to apply a custom color format. For example, if the
                  configuration file expects colors to be prefixed with #.
                '';
              };

              reloadScript = mkOption {
                type = types.lines;
                default = "";
                description = "Bash script to execute when switching colorschemes";
              };

              colorOverrides = mkOption {
                type = types.attrs;
                default = { };
                example = {
                  base00 = {
                    dark = config.${ns}.colorScheme.dark.palette.base00;
                    light = config.${ns}.colorScheme.light.palette.base02;
                  };
                };
                description = ''
                  Attribute set of base colors with dark and light variants that will
                  override the default base color map.
                '';
              };

              extraReplacements = mkOption {
                type = with types; listOf attrs;
                default = [ ];
                example = [
                  {
                    dark = "opacity = 0.7";
                    light = "opacity = 1";
                  }
                ];
                description = ''
                  List of additional replacements that are not related to base
                  colors. Cyclic replacements will not work.
                '';
              };
            };
          }
        );
        default = { };
        example = {
          waybar.paths = [
            "waybar/config"
            "waybar/style.css"
          ];
        };
        description = ''
          Attribute set of applications that should have color scheme switching
          applied to them.
        '';
      };
    };

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

      dependencyUnit = mkOption {
        type = types.str;
        default = "graphical-session.target";
        example = "swww.service";
        description = ''
          The dependency unit for the set-wallpaper service.
          graphical-session.target will always work but using the specific
          wallpaper setter service may provide less delay.
        '';
      };

      randomise = {
        enable = mkEnableOption "random wallpaper selection";

        frequency = mkOption {
          type = types.str;
          default = "weekly";
          description = ''
            How often to randomly select a new wallpaper. Format is for the systemd timer OnCalendar option.
          '';
          example = "monthly";
        };
      };

      setWallpaperCmd = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Command for setting the wallpaper. Must accept the wallpaper image path appended as an argument.
        '';
      };
    };
  };
}
