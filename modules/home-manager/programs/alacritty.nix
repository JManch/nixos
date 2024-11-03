{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf singleton;
  inherit (config.${ns}) desktop;
  cfg = config.${ns}.programs.alacritty;
  colors = config.colorScheme.palette;
  normalFontSize = 12;
  largeFontSize = 17;
in
mkIf cfg.enable {
  programs.alacritty = {
    enable = true;

    settings = {
      mouse.hide_when_typing = true;
      scrolling.history = 10000;

      window = {
        padding = {
          x = 5;
          y = 5;
        };
        dynamic_padding = true;
        decorations = "none";
        opacity = 0.7;
        dynamic_title = true;
      };

      font = {
        size = normalFontSize;
        normal = {
          family = desktop.style.font.family;
          style = "Regular";
        };
      };

      colors = {
        primary = {
          background = "#${colors.base00}";
          foreground = "#${colors.base05}";
          bright_foreground = "#${colors.base06}";
        };

        normal = {
          black = "#${colors.base02}";
          red = "#${colors.base08}";
          green = "#${colors.base0B}";
          yellow = "#${colors.base0A}";
          blue = "#${colors.base0D}";
          magenta = "#${colors.base0E}";
          cyan = "#${colors.base0C}";
          white = "#${colors.base07}";
        };
      };

      cursor = {
        blink_interval = 500;
        style = {
          shape = "Beam";
          blinking = "On";
        };
      };

      keyboard.bindings = [
        {
          key = "K";
          mods = "Alt";
          action = "ScrollLineUp";
        }
        {
          key = "J";
          mods = "Alt";
          action = "ScrollLineDown";
        }
        {
          key = "D";
          mods = "Alt";
          action = "ScrollHalfPageDown";
        }
        {
          key = "U";
          mods = "Alt";
          action = "ScrollHalfPageUp";
        }
      ];
    };
  };

  darkman.switchApps.alacritty = {
    paths = [ ".config/alacritty/alacritty.toml" ];

    extraReplacements = singleton {
      dark = "opacity = 0.7";
      light = "opacity = 1";
    };
  };

  programs.zsh.shellAliases = {
    alacritty-large-font = "alacritty msg config font.size=${toString largeFontSize}";
    alacritty-normal-font = "alacritty msg config font.size=${toString normalFontSize}";
  };

  desktop.hyprland.binds = [
    "${desktop.hyprland.modKey}, Return, exec, alacritty"
    "${desktop.hyprland.modKey}SHIFT, Return, workspace, emptym"
    "${desktop.hyprland.modKey}SHIFT, Return, exec, alacritty"
  ];
}
