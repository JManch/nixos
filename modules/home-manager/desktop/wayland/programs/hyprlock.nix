{
  ns,
  lib,
  pkgs,
  inputs,
  config,
  isWayland,
  ...
}:
let
  inherit (lib) mkIf singleton;
  inherit (config.${ns}) desktop;
  cfg = config.${ns}.desktop.programs.hyprlock;
  colors = config.colorScheme.palette;
in
mkIf (cfg.enable && isWayland) {
  ${ns}.desktop.programs.locking.package = config.programs.hyprlock.package;

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
        position = "0, 60";
        halign = "center";
        valign = "center";
      };

      input-field = singleton {
        monitor = "";
        size = "447, 60";
        fade_on_empty = false;
        outline_thickness = 3;
        dots_size = 0.2;
        dots_spacing = 0.2;
        dots_center = true;
        inner_color = "0xff${colors.base00}";
        outer_color = "0xff${colors.base07}";
        font_color = "0xff${colors.base07}";
        check_color = "0xff${colors.base0D}";
        fail_color = "0xff${colors.base08}";
        placeholder_text = "<span foreground=\"##${colors.base03}\">Password...</span>";
        fail_text = "<span foreground=\"##${colors.base08}\">Incorrect password</span>";
        hide_input = false;
        position = "0, -60";
        rounding = 10;
        halign = "center";
        valign = "center";
      };
    };
  };
}
