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
  loginctl = getExe' pkgs.systemd "loginctl";
in
{
  asserts = [
    (locker.package != null)
    "Hypridle requires a locker to be set"
  ];

  # TODO: Create a generic "idler" module like locker.nix
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
        before_sleep_cmd = "${loginctl} lock-session";
        inhibit_sleep = 3;
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
    Unit = {
      After = mkForce [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.ScreenSaver";
      Slice = "background${sliceSuffix osConfig}.slice";
    };
  };

  ns.desktop.programs.locker = mkIf (isHyprland config && !vmVariant) {
    postLockScript =
      # bash
      ''
        # Turn off the display after locking. I've found that doing this in the
        # lock script is more reliable than adding another listener.

        dpms_state_dir="/tmp/hypridle-dpms-state"
        rm -rf "$dpms_state_dir"
        mkdir "$dpms_state_dir"

        dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null |
          while read -r line; do
            # Check for sleep prepare or sleep resume events
            if echo "$line" | grep -q "PrepareForSleep"; then
              touch "$dpms_state_dir/sleep_delay"
            fi
          done &

        while true; do
          # If the display is on, wait screenOffTime seconds then turn off
          # display. Then wait the full lock time before checking again.
          if hyprctl monitors -j | jaq -e "first(.[] | select(.dpmsStatus == true))" &>/dev/null; then
            cursor_pos=$(hyprctl cursorpos)
            sleep ${toString cfg.screenOffTime}
            if [[ "$cursor_pos" != "$(hyprctl cursorpos)" ]]; then continue; fi

            # If a sleep action just happened then delay the next dpms off
            if [[ -f "$dpms_state_dir/sleep_delay" ]]; then
              rm "$dpms_state_dir/sleep_delay"
              continue
            fi

            hyprctl dispatch dpms off
          fi
          # give screens time to turn off and prolong next countdown
          sleep ${toString cfg.lockTime}
        done &
      '';

    postUnlockScript = "rm -rf /tmp/hypridle-dpms-state";
  };
}
