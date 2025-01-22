{
  lib,
  pkgs,
  inputs,
  config,
  osConfig,
  desktopEnabled,
  ...
}:
let
  inherit (lib) ns mkIf singleton;
  inherit (config.${ns}) desktop;
  inherit (osConfig.${ns}.device) primaryMonitor;
  cfg = config.${ns}.desktop.programs.hyprlock;
  colors = config.colorScheme.palette;
  labelHeight = toString (builtins.ceil (0.035 * primaryMonitor.height * primaryMonitor.scale));
in
mkIf (cfg.enable && desktopEnabled) {
  ${ns}.desktop.programs.locker = {
    package = config.programs.hyprlock.package;
    immediateFlag = "--immediate";
  };

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
        font_size = builtins.ceil (0.046875 * primaryMonitor.width * primaryMonitor.scale);
        font_family = desktop.style.font.family;
        position = "0, ${labelHeight}";
        halign = "center";
        valign = "center";
      };

      input-field = singleton {
        monitor = "";
        size = "${
          toString (builtins.ceil (0.175 * primaryMonitor.width * primaryMonitor.scale))
        }, ${labelHeight}";
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
        position = "0, -${labelHeight}";
        rounding = desktop.style.cornerRadius;
        halign = "center";
        valign = "center";
      };
    };
  };
}
