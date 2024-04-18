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

    package = pkgs.fuzzel.overrideAttrs (final: prev: {
      version = "2024-02-27";
      src = pkgs.fetchFromGitea {
        domain = "codeberg.org";
        owner = "dnkl";
        repo = final.pname;
        rev = "f4df3e4539d159eaa68aaf55633443fbd820b9f6";
        hash = "sha256-ZvMIiIXbYoIM8F+zEe+Y60e2TeqMeObGgc3ENJsDVXI=";
      };
    });

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
