{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf optionalString;
  cfg = config.modules.desktop.programs.swaylock;
  desktopCfg = config.modules.desktop;
  isWayland = lib.fetchers.isWayland config;
  colors = config.colorscheme.palette;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;

  lockScript =
    let
      isHyprland = (desktopCfg.windowManager == "hyprland");
      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
      osAudio = osConfig.modules.system.audio;
      wpctl = "${pkgs.wireplumber}/bin/wpctl";
      hyprCfg = config.modules.desktop.hyprland;
      sleep = "${pkgs.coreutils}/bin/sleep";
      grep = "${pkgs.gnugrep}/bin/grep";
      pgrep = "${pkgs.procps}/bin/pgrep";
      echo = "${pkgs.coreutils}/bin/echo";
      cut = "${pkgs.coreutils}/bin/cut";
      kill = "${pkgs.coreutils}/bin/kill";
      realpath = "${pkgs.coreutils}/bin/realpath";
      bash = "${pkgs.bash}/bin/bash";
      tr = "${pkgs.coreutils}/bin/tr";

      preLock = /*bash*/ ''

        # Store audio volumes and mute 
        ${optionalString osAudio.enable ''
          SINK_VOLUME=$(${wpctl} get-volume @DEFAULT_AUDIO_SINK@ | ${cut} -c 9-)
          SOURCE_VOLUME=$(${wpctl} get-volume @DEFAULT_AUDIO_SOURCE@ | ${cut} -c 9-)
          ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 0
          ${wpctl} set-volume @DEFAULT_AUDIO_SOURCE@ 0
        ''}

        ${cfg.preLockScript}

      '';

      postLock = cfg.postLockScript;

      postUnlock = /*bash*/ ''

        # Restore audio volumes
        ${optionalString osAudio.enable ''
          ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ $SINK_VOLUME
          ${wpctl} set-volume @DEFAULT_AUDIO_SOURCE@ $SOURCE_VOLUME
        ''}

        ${cfg.postUnlockScript}

      '';
    in
    pkgs.writeShellScript "lock-script" /*bash*/ ''
      # Abort if swaylock is already running
      ${pgrep} -x swaylock && exit 1

      # Get PIDs of existing instances of script
      pids=$(${pgrep} -fx "${bash} $(${realpath} "$0")")

      # Exlude this script's pid from the pids
      pids=$(${echo} "$pids" | ${grep} -v "$$")

      if [ ! -z "$pids" ]; then
        # Kill all existing instances of the script
        pid_list=$(${echo} "$pids" | ${tr} '\n' ' ')
        ${kill} $pid_list
      fi

      ${preLock}
      ${config.programs.swaylock.package}/bin/swaylock &
      SWAYLOCK_PID=$!
      ${postLock}
      wait $SWAYLOCK_PID
      ${postUnlock}
    '';
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
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
    lib.mkIf (config.modules.desktop.windowManager == "hyprland")
      [ "${config.modules.desktop.hyprland.modKey}, Space, exec, ${lockScript.outPath}" ];
}
