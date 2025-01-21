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
  cfg = config.${ns}.desktop.services;
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
    wayvnc.enable = mkEnableOption "WayVNC";

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
      defaults = {
        default = mkOption {
          type = types.package;
          default = inputs.nix-resources.packages.${pkgs.system}.wallpapers.rx7;
          description = ''
            The default wallpaper to use if randomise is disabled.
          '';
        };

        dark = mkOption {
          type = types.package;
          default = cfg.wallpaper.defaults.default;
          description = ''
            The dark theme wallpaper to use if randomise is disabled and
            darkman is enabled.
          '';
        };

        light = mkOption {
          type = types.package;
          default = cfg.wallpaper.defaults.default;
          description = ''
            The light theme wallpaper to use if randomise is disabled and
            darkman is enabled.
          '';
        };
      };

      wallpaperUnit = mkOption {
        type = types.str;
        example = "swww.service";
        description = ''
          Unit of the wallpaper managager.
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
        type = with types; nullOr str;
        default = null;
        description = ''
          Command for setting the wallpaper. Must accept the wallpaper image path appended as an argument.
        '';
      };
    };

    waybar = {
      enable = mkEnableOption "Waybar";

      audioDeviceIcons = mkOption {
        type = with types; attrsOf str;
        default = { };
        description = ''
          Attribute set mapping audio devices to icons. Use pamixer --list-sinks to get device names.
        '';
      };

      autoHideWorkspaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of workspace names that, when activated, cause the bar to
          automatically hide. Only works on Hyprland.
        '';
      };
    };

    wlsunset = {
      enable = mkEnableOption "wlsunset";
      restartAfterDPMS = mkEnableOption "restarting after DPMS";

      transition = mkEnableOption ''
        gradually transitioning the screen temperature until sunset instead of
        suddenly switching at the set time. Warning: this tends to cause
        stuttering and artifacting as the transition is happening.
      '';
    };

    hypridle = {
      enable = mkEnableOption "Hypridle";
      debug = mkEnableOption "a low timeout idle notification for debugging";

      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Idle seconds to lock screen";
      };

      suspendTime = mkOption {
        type = with types; nullOr int;
        default = null;
        description = "Idle seconds to suspend";
      };

      screenOffTime = mkOption {
        type = types.int;
        default = 30;
        description = "Seconds to turn off screen after locking";
      };
    };
  };
}
