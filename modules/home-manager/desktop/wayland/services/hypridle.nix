{ lib
, pkgs
, inputs
, config
, ...
}:
let
  inherit (lib) mkIf optional mkForce getExe getExe';
  cfg = desktopCfg.services.hypridle;
  desktopCfg = config.modules.desktop;
  swaylock = desktopCfg.programs.swaylock;
in
{
  imports = [
    inputs.hypridle.homeManagerModules.default
  ];

  config = mkIf (cfg.enable && swaylock.enable) {
    services.hypridle = {
      enable = true;
      lockCmd = swaylock.lockScript;
      ignoreDbusInhibit = false;

      listeners = [{
        timeout = cfg.lockTime;
        onTimeout = swaylock.lockScript;
      }] ++ optional cfg.debug {
        timeout = 5;
        onTimeout = "${lib.getExe pkgs.libnotify} 'Hypridle' 'Idle timeout triggered'";
      };
    };

    modules.desktop.programs.swaylock.postLockScript =
      let
        sleep = getExe' pkgs.coreutils "sleep";
        date = getExe' pkgs.coreutils "date";
        hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
        jaq = getExe pkgs.jaq;
      in
        /*bash*/ ''

        # Turn off the display after locking. I've found that doing this in the
        # lock script is more reliable than adding another listener.
        lockfile="/tmp/dpms-lock-$$-$(${date} +%s)"
        touch "$lockfile"
        trap 'rm -f "$lockfile"' EXIT
        while true; do
          # If the display is on, wait screenOffTime seconds then turn off
          # display. Then wait the full lock time before checking again.
          if '${hyprctl}' monitors -j | ${jaq} -e "first(.[] | select(.dpmsStatus == true))" >/dev/null 2>&1; then
            ${sleep} ${toString cfg.screenOffTime}
            if [ ! -e "$lockfile" ]; then exit 1; fi
            '${hyprctl}' dispatch dpms off
          fi
          # give screens time to turn off and prolong next countdown
          ${sleep} ${toString cfg.lockTime}
        done &

      '';

    systemd.user.services.hypridle = {
      Unit.PartOf = [ "graphical-session.target" ];
      Unit.After = mkForce [ "graphical-session-pre.target" ];
      Install.WantedBy = mkForce [ "graphical-session.target" ];
    };
  };
}
