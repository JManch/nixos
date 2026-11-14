{ lib, config }:
let
  inherit (lib) ns;
  inherit (lib.${ns}) mkHyprExec;
  inherit (config.${ns}.desktop.style) font;
  wl-kbptr = "/run/wrappers/bin/wl-kbptr";
in
{
  ns.desktop.hyprland.binds = [
    (mkHyprExec "mod" "F" wl-kbptr)
    (mkHyprExec "mod_shift" "F" "${wl-kbptr} -o mode_click.button=right")
    (mkHyprExec "mod" "G" "${wl-kbptr} -o modes=tile,bisect")
  ];

  xdg.configFile."wl-kbptr/config".text = lib.generators.toINI { } {
    general = {
      modes = "floating,click";
      key_source = "evdev";
    };

    mode_floating = {
      label_font_family = font.family;
      source = "detect";
    };

    mode_tile = {
      label_font_family = font.family;
      label_symbols = "sadfjklewcmpgh";
    };

    mode_bisect.label_font_size = "12 50% 100";
  };
}
