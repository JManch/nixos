{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers getExe getExe';
  cfg = desktopCfg.programs.fuzzel;
  desktopCfg = config.modules.desktop;
  colors = config.colorScheme.palette;
in
mkIf (cfg.enable && osConfig.usrEnv.desktop.enable && (fetchers.isWayland config))
{
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        font = "${desktopCfg.style.font.family}:size=18";
        lines = 5;
        width = 30;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 5;

        tabs = 4;
        prompt = "\"\"";
        icons-enabled = true;
        terminal = "${desktopCfg.terminal.exePath} -e";
        icon-theme = config.gtk.iconTheme.name;
        layer = "overlay";
      };

      colors = {
        background = "${colors.base00}ff";
        text = "${colors.base07}ff";
        match = "${colors.base07}ff";
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

  darkman.switchApps.fuzzel = {
    paths = [ "fuzzel/fuzzel.ini" ];
  };

  desktop.hyprland.settings.bindr =
    let
      inherit (desktopCfg.hyprland) modKey;
      fuzzel = getExe pkgs.fuzzel;
    in
    [
      "${modKey}, ${modKey}_L, exec, ${getExe' pkgs.procps "pkill"} fuzzel || ${fuzzel}"
    ];
}
