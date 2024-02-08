{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  cfg = config.modules.desktop.programs.swaylock;
  desktopCfg = config.modules.desktop;
  isWayland = lib.fetchers.isWayland config;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
  colors = config.colorscheme.palette;
in
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
      # Turn off screen after 30 seconds if swaylock is still running
      lockBindScript =
        let
          hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
          sleep = "${pkgs.coreutils}/bin/sleep";
          grep = "${pkgs.gnugrep}/bin/grep";
          pgrep = "${pkgs.procps}/bin/pgrep";
          echo = "${pkgs.coreutils}/bin/echo";
          kill = "${pkgs.coreutils}/bin/kill";
          realpath = "${pkgs.coreutils}/bin/realpath";
          bash = "${pkgs.bash}/bin/bash";
          tr = "${pkgs.coreutils}/bin/tr";
        in
        pkgs.writeShellScript "hypr-lock-script" ''
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

          ${cfg.lockScript}
          ${sleep} 30
          ${pgrep} -x swaylock && ${hyprctl} dispatch dpms off
        '';
    in
    lib.mkIf (config.modules.desktop.windowManager == "hyprland")
      # TODO: Add lock and unlock scripts ran before and after locking to mute
      # system audio and mic
      [ "${config.modules.desktop.hyprland.modKey}, Space, exec, ${lockBindScript.outPath}" ];
}
