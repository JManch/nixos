{
  lib,
  pkgs,
  config,
  osConfig',
  isWayland,
  ...
}:
let
  inherit (lib) mkIf utils getExe';
  inherit (osConfig'.device) primaryMonitor;
  cfg = desktopCfg.programs.swaylock;
  desktopCfg = config.modules.desktop;
  colors = config.colorScheme.palette;
  isHyprland = utils.isHyprland config;
in
mkIf (cfg.enable && isWayland) {
  modules.desktop.programs.locking = {
    package = config.programs.swaylock.package;

    # Temporarily disable hyprland shader so that screenshot doesn't get shader
    # applied twice
    preLockScript = mkIf isHyprland ''
      ${config.modules.desktop.hyprland.disableShaders}
    '';

    postLockScript = mkIf isHyprland ''
      (${getExe' pkgs.coreutils "sleep"} 0.1; ${config.modules.desktop.hyprland.enableShaders}) &
    '';
  };

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
      indicator-y-position = builtins.floor (primaryMonitor.height * 0.5);
      indicator-radius = builtins.floor (primaryMonitor.width * 4.0e-2);

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

  darkman.switchApps.swaylock = {
    paths = [ "swaylock/config" ];
  };
}
