{
  lib,
  pkgs,
  inputs,
  config,
  isWayland,
  ...
}:
let
  inherit (lib) mkIf singleton;
  inherit (config.modules) desktop;
  cfg = config.modules.desktop.programs.hyprlock;
  colors = config.colorScheme.palette;
in
mkIf (cfg.enable && isWayland) {
  modules.desktop.programs.locking.package = config.programs.hyprlock.package;

  programs.hyprlock = {
    enable = true;
    package = inputs.hyprlock.packages.${pkgs.system}.default;
    settings = {
      general = {
        hide_cursor = false;
        grace = 3;
      };

      background = singleton {
        monitor = "";
        path = "screenshot";
        blur_size = 2;
        blur_passes = 3;
      };

      label = {
        monitor = "";
        text = "$TIME";
        color = "0xff${colors.base07}";
        font_size = 120;
        font_family = desktop.style.font.family;
        position = "0, 150";
        halign = "center";
        valign = "center";
      };

      input-field = singleton {
        monitor = "";
        size = "350, 60";
        fade_on_empty = false;
        outline_thickness = 0;
        dots_size = 0.2;
        dots_spacing = 0.2;
        dots_center = true;
        inner_color = "0xff${colors.base00}";
        font_color = "0xff${colors.base07}";
        placeholder_text = "<i><span foreground=\"##${colors.base07}99\">Password...</span></i>";
        hide_input = false;
        position = "0, -150";
        halign = "center";
        valign = "center";
      };
    };
  };
}
