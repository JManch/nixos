{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf optionalString fetchers getExe;
  cfg = desktopCfg.programs.swaylock;
  desktopCfg = config.modules.desktop;
  isWayland = fetchers.isWayland config;
  colors = config.colorscheme.palette;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;

  lockScript =
    let
      osAudio = osConfig.modules.system.audio;
      preLock = /*bash*/ ''

        # Store audio volumes and mute 
        ${optionalString osAudio.enable ''
          sink_volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | cut -c 9-)
          source_volume=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | cut -c 9-)
          wpctl set-volume @DEFAULT_AUDIO_SINK@ 0
          wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0
        ''}
        ${cfg.preLockScript}

      '';

      postLock = cfg.postLockScript;

      postUnlock = /*bash*/ ''

        # Restore audio volumes
        ${optionalString osAudio.enable ''
          wpctl set-volume @DEFAULT_AUDIO_SINK@ "$sink_volume"
          wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$source_volume"
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

        # Abort if swaylock is already running
        pgrep -x swaylock && exit 1

        # Get PIDs of existing instances of script
        pids=$(pgrep -fx "${getExe pkgs.bash} $(realpath "$0")" || true)

        # Exlude this script's pid from the pids
        pids=$(echo "$pids" | grep -v "$$")

        if [ -n "$pids" ]; then
          # Kill all existing instances of the script
          pid_list=$(echo "$pids" | tr '\n' ' ')
          kill "$pid_list" || true
        fi

        ${preLock}
        ${getExe config.programs.swaylock.package} &
        SWAYLOCK_PID=$!
        ${postLock}
        wait $SWAYLOCK_PID
        ${postUnlock}

      '';
    };
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
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

  desktop.hyprland.binds =
    let
      inherit (config.modules.desktop.hyprland) modKey;
    in
    [ "${modKey}, Space, exec, ${getExe lockScript}" ];
}
