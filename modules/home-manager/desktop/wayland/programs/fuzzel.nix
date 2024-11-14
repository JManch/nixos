{
  ns,
  lib,
  config,
  osConfig',
  isWayland,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (osConfig'.${ns}.device) primaryMonitor;
  inherit (osConfig'.programs) uwsm;
  cfg = desktopCfg.programs.fuzzel;
  desktopCfg = config.${ns}.desktop;
  colors = config.colorScheme.palette;
in
mkIf (cfg.enable && isWayland) {
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        launch-prefix = mkIf uwsm.enable "uwsm app --";
        terminal = "xdg-terminal-exec";

        font = "${desktopCfg.style.font.family}:size=18";
        lines = 5;
        width = 30;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 5;
        anchor = "bottom";
        y-margin = builtins.floor (primaryMonitor.height * 0.43);

        tabs = 4;
        prompt = "\"\"";
        icons-enabled = true;
        terminal = "${desktopCfg.terminal.exePath} -e";
        icon-theme = config.gtk.iconTheme.name;
      };

      colors = {
        background = "${colors.base00}ff";
        input = "${colors.base07}ff";
        text = "${colors.base05}ff";
        match = "${colors.base05}ff";
        selection = "${colors.base00}ff";
        selection-text = "${colors.base07}ff";
        selection-match = "${colors.base07}ff";
        border = "${colors.base0D}ff";
      };

      border = {
        width = 2;
        radius = desktopCfg.style.cornerRadius;
      };
    };
  };

  darkman.switchApps.fuzzel =
    let
      inherit (config.${ns}.colorScheme) dark light;
    in
    {
      paths = [ ".config/fuzzel/fuzzel.ini" ];
      colorOverrides = {
        base05 = {
          dark = dark.palette.base05;
          light = light.palette.base04;
        };
      };
    };

  desktop.hyprland.settings =
    let
      inherit (desktopCfg.hyprland) modKey;
    in
    {
      bindr = [
        "${modKey}, ${modKey}_L, exec, pkill fuzzel || fuzzel"
      ];
      layerrule = [ "animation slide, launcher" ];
    };
}
