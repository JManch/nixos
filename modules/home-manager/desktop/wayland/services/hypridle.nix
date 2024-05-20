{ lib
, pkgs
, inputs
, config
, ...
}:
let
  inherit (lib) mkIf utils optional mkForce getExe getExe' escapeShellArg;
  inherit (config.modules.desktop.programs) swaylock;
  cfg = config.modules.desktop.services.hypridle;
in
{
  imports = [
    inputs.hypridle.homeManagerModules.default
  ];

  disabledModules = [ "${inputs.home-manager}/modules/services/hypridle.nix" ];

  config = mkIf cfg.enable {
    assertions = utils.asserts [
      swaylock.enable
      "Hypridle requires Swaylock to be enabled"
    ];

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
          if ${escapeShellArg hyprctl} monitors -j | ${jaq} -e "first(.[] | select(.dpmsStatus == true))" >/dev/null 2>&1; then
            ${sleep} ${toString cfg.screenOffTime}
            if [ ! -e "$lockfile" ]; then exit 1; fi
            ${escapeShellArg hyprctl} dispatch dpms off
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

    wayland.windowManager.hyprland.settings.bind =
      let
        inherit (config.modules.desktop.hyprland) modKey;
        systemctl = getExe' pkgs.systemd "systemctl";
        notifySend = getExe pkgs.libnotify;
        toggleHypridle = pkgs.writeShellScript "hypridle-toggle" ''
          ${systemctl} is-active --quiet --user hypridle && {
            ${systemctl} stop --quiet --user hypridle
            ${notifySend} --urgency=low -t 2000 'Hypridle' 'Service disabled'
          } || {
            ${systemctl} start --quiet --user hypridle
            ${notifySend} --urgency=low -t 2000 'Hypridle' 'Service enabled'
          }
        '';
      in
      [
        "${modKey}, U, exec, ${toggleHypridle}"
      ];
  };
}
