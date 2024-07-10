{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.programs.gaming.gamemode;

  startStopScript =
    let
      inherit (lib) optionalString utils boolToString substring stringLength toUpper optional;
      inherit (homeConfig.modules.desktop) hyprland;
      inherit (config.modules.system) desktop;
      inherit (config.device) primaryMonitor;
      homeConfig = config.home-manager.users.${username};
      isHyprland = utils.isHyprland config;

      # Remap the killactive key to use the shift modifier
      killActiveRebind = isEnd: ''
        keyword unbind ${hyprland.modKey}${optionalString isEnd "SHIFTCONTROL"}, W; \
        keyword bind ${hyprland.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive;'';

      refreshRate = m: toString (
        if (m == "start") then
          primaryMonitor.gamingRefreshRate
        else
          primaryMonitor.refreshRate
      );

      isEnd = m: boolToString (m == "end");
      blur = m: if hyprland.blur then isEnd m else "false";
      notifBody = m: ((toUpper (substring 0 1 m)) + (substring 1 ((stringLength m) - 1) m));
    in
    mode: pkgs.writeShellApplication {
      name = "gamemode-${mode}";

      runtimeInputs = [
        pkgs.coreutils
        pkgs.libnotify
        pkgs.gnugrep
      ] ++ optional isHyprland homeConfig.wayland.windowManager.hyprland.package;

      text = ''
        # Load custom arguments into positional parameters
        args_file="/home/${username}/.gamemode-custom-args"
        if [ -e "$args_file" ]; then
          set -- "$(cat "$args_file")"
          rm "$args_file"
        fi

        ${
          optionalString isHyprland /*bash*/ ''
            hyprctl --instance 0 --batch "\
              ${optionalString hyprland.blur "keyword decoration:blur:enabled ${blur mode};\\"}
              keyword monitor ${utils.getMonitorHyprlandCfgStr (primaryMonitor // {refreshRate = refreshRate mode;})}; \
              ${killActiveRebind (mode == "end")}"
          ''
        }

        ${if mode == "start" then cfg.startScript else cfg.stopScript}

        ${
          optionalString (desktop.desktopEnvironment == null) /*bash*/ ''
            notify-send --urgency=critical -t 2000 \
              -h 'string:x-canonical-private-synchronous:gamemode-toggle' 'GameMode' '${notifBody mode}ed'
          ''
        }
      '';
    };
in
mkIf cfg.enable
{
  # Do not start gamemoded for system users. This prevents gamemoded starting
  # during login when greetd temporarily runs as the greeter user.
  systemd.user.services.gamemoded = {
    unitConfig.ConditionUser = "!@system";
  };

  # Since version 1.8 gamemode requires the user to be in the gamemode group
  # https://github.com/FeralInteractive/gamemode/issues/452
  users.users.${username}.extraGroups = [ "gamemode" ];

  nixpkgs.overlays = [
    (final: prev: {
      gamemode = prev.gamemode.overrideAttrs (old: {
        # This allows us to pass custom arguments to gamemoderun. For example,
        # passing --high-perf sets a higher GPU power cap in our start script.
        # The custom arguments must be the first arguments passed to
        # gamemoderun. We have to write to a file like this because it's better
        # to run the script in the gamemode environment than in steam's FHS
        # environment where a bunch of stuff (like lib-notify) doesn't work.

        # We can't write to /tmp because steam runs in a chroot with its own
        # tmp dir. Any files we write there will not be accessible from our
        # gamemoderun start script. Our home directory is bind mounted in the
        # chroot so that is accessible.
        postFixup = old.postFixup + ''
          wrapProgram $out/bin/gamemoderun --run '
          rm -f /home/${username}/.gamemode-custom-args
          while test $# -gt 0
          do
            case "$1" in
              --high-perf)
                ;&
              --low-perf) echo -n "$1 " >> /home/${username}/.gamemode-custom-args;
                ;;
              *) break
                ;;
            esac
            shift
          done
          '
        '';
      });
    })
  ];

  programs.gamemode = {
    enable = true;

    settings = {
      custom = {
        # WARN: For gamemode script changes to be applied the user service must
        # be manually restarted with `systemctl restart --user gamemoded`
        start = getExe (startStopScript "start");
        end = getExe (startStopScript "end");
      };
    };
  };
}
