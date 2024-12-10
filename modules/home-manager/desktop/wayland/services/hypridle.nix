{
  lib,
  pkgs,
  inputs,
  config,
  isWayland,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    optional
    getExe
    getExe'
    escapeShellArg
    singleton
    ;
  inherit (lib.${ns}) asserts isHyprland;
  inherit (config.${ns}.desktop.programs) locking;
  cfg = config.${ns}.desktop.services.hypridle;
in
mkIf (cfg.enable && isWayland) {
  assertions = asserts [
    (locking.package != null)
    "Hypridle requires a locker to be enabled"
  ];

  services.hypridle = {
    enable = true;
    package = inputs.hypridle.packages.${pkgs.system}.default;
    settings = {
      general = {
        lock_cmd = locking.lockScript;
        ignore_dbus_inhibit = false;
      };

      listener =
        (singleton {
          timeout = cfg.lockTime;
          on-timeout = "${getExe' pkgs.systemd "loginctl"} lock-session";
        })
        ++ optional cfg.debug {
          timeout = 5;
          on-timeout = "${getExe pkgs.libnotify} 'Hypridle' 'Idle timeout triggered'";
        };
    };
  };

  systemd.user.services.hypridle = {
    Unit.After = mkForce [ "graphical-session.target" ];
    Service.Slice = [ "background-graphical.slice" ];
  };

  ${ns}.desktop.programs.locking.postLockScript =
    let
      hyprctl = escapeShellArg (getExe' config.wayland.windowManager.hyprland.package "hyprctl");
      jaq = getExe pkgs.jaq;
    in
    mkIf (isHyprland config)
      # bash
      ''
        # Turn off the display after locking. I've found that doing this in the
        # lock script is more reliable than adding another listener.
        while true; do
          # If the display is on, wait screenOffTime seconds then turn off
          # display. Then wait the full lock time before checking again.
          if ${hyprctl} monitors -j | ${jaq} -e "first(.[] | select(.dpmsStatus == true))" >/dev/null 2>&1; then
            sleep ${toString cfg.screenOffTime}
            if [ ! -e "$lockfile" ]; then exit 1; fi
            ${hyprctl} dispatch dpms off
          fi
          # give screens time to turn off and prolong next countdown
          sleep ${toString cfg.lockTime}
        done &
      '';

  wayland.windowManager.hyprland.settings.bind =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;
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
    [ "${modKey}, U, exec, ${toggleHypridle}" ];
}
