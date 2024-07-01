{ lib
, pkgs
, config
, osConfig
, isWayland
, desktopEnabled
, ...
}:
let
  inherit (lib) mkIf optionalString getExe;
  cfg = desktopCfg.programs.swaylock;
  desktopCfg = config.modules.desktop;
  colors = config.colorScheme.palette;

  lockScript =
    let
      osAudio = osConfig.modules.system.audio;
      preLock = /*bash*/ ''
        ${optionalString osAudio.enable ''
          wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
          wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
        ''}
        ${cfg.preLockScript}
      '';

      postLock = cfg.postLockScript;

      postUnlock = /*bash*/ ''
        ${optionalString osAudio.enable ''
          wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
          wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
        ''}
        ${cfg.postUnlockScript}
      '';
    in
    pkgs.writeShellApplication {
      name = "swaylock-lock-script";

      runtimeInputs = with pkgs; [
        wireplumber
        gnugrep
        procps
        coreutils
      ];

      text = /*bash*/ ''

        # Exit if swaylock is running
        pgrep -x swaylock && exit 1

        # Create a unique lock file so forked processes can track if precisely
        # this instance of swaylock is still running
        lockfile="/tmp/swaylock-lock-$$-$(date +%s)"
        touch "$lockfile"
        trap 'rm -f "$lockfile"' EXIT

        ${preLock}
        ${getExe config.programs.swaylock.package} &
        SWAYLOCK_PID=$!
        ${postLock}
        wait $SWAYLOCK_PID
        ${postUnlock}

      '';
    };
in
mkIf (cfg.enable && desktopEnabled && isWayland) {
  modules.desktop.programs.swaylock.lockScript = getExe lockScript;

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
      indicator-y-position = builtins.floor ((lib.fetchers.primaryMonitor osConfig).height * 0.5);
      indicator-radius = builtins.floor ((lib.fetchers.primaryMonitor osConfig).width * 0.04);

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

  desktop.hyprland.binds =
    let
      inherit (config.modules.desktop.hyprland) modKey;
    in
    [ "${modKey}, Space, exec, ${getExe lockScript}" ];
}
