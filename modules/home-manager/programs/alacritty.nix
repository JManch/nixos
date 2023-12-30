{ config
, osConfig
, lib
, ...
}:
let
  binary = "${config.programs.alacritty.package}/bin/alacritty";
  cfg = config.modules.programs.alacritty;
in
lib.mkIf cfg.enable {
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 5;
          y = 5;
        };
        dynamic_padding = true;
        decorations = "none";
        opacity = cfg.opacity;
        dynamic_title = true;
      };
      scrolling = {
        history = 10000;
      };
      font = {
        size = 14;
        normal = {
          family = "${config.modules.desktop.font.family}";
          style = "Regular";
        };
      };
      colors = {
        primary = {
          background = "#${config.colorscheme.colors.base01}";
          foreground = "#${config.colorscheme.colors.base05}";
          bright_foreground = "#${config.colorscheme.colors.base06}";
        };
        normal = {
          black = "#${config.colorscheme.colors.base00}";
          red = "#${config.colorscheme.colors.base08}";
          green = "#${config.colorscheme.colors.base0B}";
          yellow = "#${config.colorscheme.colors.base0A}";
          blue = "#${config.colorscheme.colors.base0D}";
          magenta = "#${config.colorscheme.colors.base0E}";
          cyan = "#${config.colorscheme.colors.base0C}";
          white = "#${config.colorscheme.colors.base07}";
        };
      };
      mouse = {
        hide_when_typing = true;
      };
      cursor = {
        style = {
          shape = "Beam";
          blinking = "On";
        };
        blink_interval = 500;
      };
    };
  };
  desktop.hyprland.binds = lib.mkIf (osConfig.usrEnv.desktop.compositor == "hyprland")
    [ "${config.modules.desktop.hyprland.modKey}, Return, exec, ${binary}" ];
}
