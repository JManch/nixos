{ pkgs
, config
, nixosConfig
, lib
, ...
}:
let
  inherit (config.colorscheme) colors;
  cfg = config.modules.desktop.swaylock;
  desktopCfg = config.modules.desktop;
  isWayland = lib.fetchers.isWayland config;
  lockScript = pkgs.writeShellScript "lock-script" config.modules.desktop.swaylock.lockScript;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
# TODO: Try and fix swaylock not locking sometimes
lib.mkIf (osDesktopEnabled && isWayland && cfg.enable) {
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      screenshots = true;
      line-uses-inside = true;
      grace = 3;
      clock = true;
      datestr = "%e %B %Y";

      font = desktopCfg.style.font.family;
      font-size = 25;

      effect-blur = "10x3";
      fade-in = 0;

      disable-caps-lock-text = true;
      show-failed-attempts = true;

      indicator = true;
      indicator-caps-lock = true;
      indicator-y-position = builtins.floor ((lib.fetchers.primaryMonitor nixosConfig).height * 0.5);
      indicator-radius = builtins.floor ((lib.fetchers.primaryMonitor nixosConfig).width * 0.04);

      text-color = "#${colors.base07}";

      inside-color = "#${colors.base00}";
      ring-color = "#${colors.base00}";
      separator-color = "#${colors.base00}";

      inside-wrong-color = "#${colors.base08}";
      ring-wrong-color = "#${colors.base08}";
      bs-hl-color = "#${colors.base08}";
      text-wrong-color = "#${colors.base01}";

      key-hl-color = "#${colors.base0B}";
      ring-ver-color = "#${colors.base0B}";
      inside-ver-color = "#${colors.base0B}";
      text-ver-color = "#${colors.base01}";

      inside-clear-color = "#${colors.base0D}";
      ring-clear-color = "#${colors.base0D}";
      text-clear-color = "#${colors.base01}";

      text-caps-lock-color = "#${colors.base07}";
      inside-caps-lock-color = "#${colors.base00}";
      ring-caps-lock-color = "#${colors.base0E}";
    };
  };

  desktop.hyprland.binds =
    lib.mkIf (config.modules.desktop.windowManager == "hyprland")
      [ "${config.modules.desktop.hyprland.modKey}, Space, exec, ${lockScript.outPath}" ];
}
