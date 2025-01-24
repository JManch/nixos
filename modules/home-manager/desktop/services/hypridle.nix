{
  lib,
  cfg,
  pkgs,
  inputs,
  config,
  osConfig,
  vmVariant,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    optional
    getExe
    getExe'
    singleton
    mkEnableOption
    mkOption
    types
    ;
  inherit (lib.${ns}) isHyprland sliceSuffix;
  inherit (config.${ns}.desktop.programs) locker;
  systemctl = getExe' pkgs.systemd "systemctl";
in
{
  asserts = [
    (locker.package != null)
    "Hypridle requires a locker to be set"
  ];

  opts = {
    debug = mkEnableOption "a low timeout idle notification for debugging";

    lockTime = mkOption {
      type = types.int;
      default = 3 * 60;
      description = "Idle seconds to lock screen";
    };

    suspendTime = mkOption {
      type = with types; nullOr int;
      default = null;
      description = "Idle seconds to suspend";
    };

    screenOffTime = mkOption {
      type = types.int;
      default = 30;
      description = "Seconds to turn off screen after locking";
    };
  };

  services.hypridle = {
    enable = true;
    package = inputs.hypridle.packages.${pkgs.system}.default;
    settings = {
      general = {
        # Cmd triggered by `loginctl lock-session`
        lock_cmd = "${locker.lockScript} --immediate";
        ignore_dbus_inhibit = false;
      };

      listener =
        (singleton {
          timeout = cfg.lockTime;
          on-timeout = locker.lockScript;
        })
        ++ optional (cfg.suspendTime != null) {
          timeout = cfg.suspendTime;
          on-timeout = "${systemctl} suspend";
        }
        ++ optional cfg.debug {
          timeout = 5;
          on-timeout = "${getExe pkgs.libnotify} 'Hypridle' 'Idle timeout triggered'";
        };
    };
  };

  systemd.user.services.hypridle = {
    Unit.After = mkForce [ "graphical-session.target" ];
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.ScreenSaver";
      Slice = "background${sliceSuffix osConfig}.slice";
    };
  };

  nsConfig.desktop.programs.locker.postLockScript =
    let
      hyprctl = getExe' pkgs.hyprland "hyprctl";
      jaq = getExe pkgs.jaq;
    in
    mkIf (isHyprland config && !vmVariant)
      # bash
      ''
        # Turn off the display after locking. I've found that doing this in the
        # lock script is more reliable than adding another listener.
        while true; do
          # If the display is on, wait screenOffTime seconds then turn off
          # display. Then wait the full lock time before checking again.
          if ${hyprctl} monitors -j | ${jaq} -e "first(.[] | select(.dpmsStatus == true))" &>/dev/null; then
            cursor_pos=$(${hyprctl} cursorpos)
            sleep ${toString cfg.screenOffTime}
            if [ "$cursor_pos" != "$(${hyprctl} cursorpos)" ]; then continue; fi
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
