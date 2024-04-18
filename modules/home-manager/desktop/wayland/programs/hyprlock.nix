{ lib
, inputs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers;
  cfg = config.modules.desktop.programs.hyprlock;
  colors = config.colorScheme.palette;

  isWayland = fetchers.isWayland config;
  primaryMonitor = fetchers.primaryMonitor osConfig;
in
{
  imports = [
    inputs.hyprlock.homeManagerModules.default
  ];

  config = mkIf (cfg.enable && isWayland) {
    programs.hyprlock = {
      enable = true;

      general = {
        disable_loading_bar = false;
        grace = 3;
        hide_cursor = true;
        no_fade_in = false;
      };

      backgrounds = [{
        path = "screenshot";
        color = "0xff${colors.base00}";
        blur_size = 2;
        blur_passes = 3;
        brightness = 1;
        contrast = 1;
      }];

      input-fields = [{
        monitor = primaryMonitor.name;
        size.width = 300;
        size.height = 40;
        outline_thickness = 3;
        outer_color = "0xff${colors.base00}";
        inner_color = "0xff${colors.base00}";
        font_color = "0xff${colors.base07}";
        fade_on_empty = true;
        placeholder_text = "";
        hide_input = false;
        position = { x = 0; y = -30; };
        halign = "center";
        valign = "center";
      }];

      labels = [{
        monitor = primaryMonitor.name;
        text = "$TIME";
        position = { x = 0; y = 30; };
        font_family = config.modules.desktop.style.font.family;
        font_size = 40;
        color = "0xff${colors.base07}";
      }];
    };
  };
}
