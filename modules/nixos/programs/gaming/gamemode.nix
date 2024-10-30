{
  ns,
  lib,
  pkgs,
  config,
  username,
  ...
}:
let
  inherit (lib) mkIf getExe hiPrio;
  cfg = config.${ns}.programs.gaming.gamemode;

  gamemoderunCustom = pkgs.symlinkJoin {
    name = "gamemoderun-custom-args";
    paths = [ pkgs.gamemode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Have to write the arguments to a file so that the gamemode start script
      # can read them from the file. I'm not aware of any other way to pass
      # custom arguments to the start script (and it does not inherit env vars)

      # We can't write to /tmp because steam runs in a chroot with its own
      # tmp dir. Any files we write there will not be accessible from our
      # gamemoderun start script. Our home directory is bind mounted in the
      # chroot so that is accessible.
      wrapProgram $out/bin/gamemoderun --run '
        rm -f "/home/${username}/.gamemode-custom-args"
        echo "$GAMEMODE_CUSTOM_ARGS" > "/home/${username}/.gamemode-custom-args"
      '
    '';
  };

  startStopScript =
    let
      inherit (lib)
        optionalString
        boolToString
        substring
        stringLength
        toUpper
        optional
        ;
      inherit (config.hm.${ns}.desktop) hyprland;
      inherit (config.${ns}.system) desktop;
      inherit (config.${ns}.device) primaryMonitor;
      isHyprland = lib.${ns}.isHyprland config;

      # Remap the killactive key to use the shift modifier
      killActiveRebind = isEnd: ''
        keyword unbind ${hyprland.modKey}${optionalString isEnd "SHIFTCONTROL"}, W; \
        keyword bind ${hyprland.modKey}${optionalString (!isEnd) "SHIFTCONTROL"}, W, killactive;'';

      refreshRate =
        m:
        toString (if (m == "start") then primaryMonitor.gamingRefreshRate else primaryMonitor.refreshRate);

      isEnd = m: boolToString (m == "end");
      blur = m: if hyprland.blur then isEnd m else "false";
      notifBody = m: ((toUpper (substring 0 1 m)) + (substring 1 ((stringLength m) - 1) m));
    in
    mode:
    pkgs.writeShellApplication {
      name = "gamemode-${mode}";

      runtimeInputs =
        (with pkgs; [
          coreutils
          libnotify
          gnugrep
        ])
        ++ optional isHyprland config.hm.wayland.windowManager.hyprland.package;

      text = ''
        # Load custom arguments from file that our wrapper wrote to
        args_file="/home/${username}/.gamemode-custom-args"
        args_array=()
        if [ -e "$args_file" ]; then
          IFS=',' read -r -a args_array <<< "$(<"$args_file")"
          rm "$args_file"
        fi

        arg_exists() {
          local arg="$1"
          for elem in "''${args_array[@]}"; do
            if [[ "$elem" == "$arg" ]]; then
              return 0
            fi
          done
          return 1
        }

        ${optionalString isHyprland # bash
          ''
            hyprCtlCommands="${optionalString hyprland.blur "keyword decoration:blur:enabled ${blur mode}"};"

            # Refresh rate and keybinds don't matter for VR
            if ! arg_exists "vr"; then
              hyprCtlCommands="$hyprCtlCommands \
                keyword monitor ${
                  lib.${ns}.getMonitorHyprlandCfgStr (primaryMonitor // { refreshRate = refreshRate mode; })
                }; \
                ${killActiveRebind (mode == "end")} \
              "
            fi

            hyprctl --instance 0 --batch "$hyprCtlCommands"
          ''
        }

        ${if mode == "start" then cfg.startScript else cfg.stopScript}

        ${optionalString (desktop.desktopEnvironment == null) # bash
          ''
            notify-send --urgency=critical -t 2000 \
              -h 'string:x-canonical-private-synchronous:gamemode-toggle' 'GameMode' '${notifBody mode}ed'
          ''
        }
      '';
    };
in
mkIf cfg.enable {
  # Do not start gamemoded for system users. This prevents gamemoded starting
  # during login when greetd temporarily runs as the greeter user.
  systemd.user.services.gamemoded = {
    unitConfig.ConditionUser = "!@system";
  };

  # Since version 1.8 gamemode requires the user to be in the gamemode group
  # https://github.com/FeralInteractive/gamemode/issues/452
  users.users.${username}.extraGroups = [ "gamemode" ];

  # This allows us to pass a comma seperated list of custom arguments to
  # gamemode start and stop scripts with the GAMEMODE_CUSTOM_ARGS env var. For
  # example, setting GAMEMODE_CUSTOM_ARGS=high-perf,vr sets a higher GPU power cap
  # in our start script and enables the VR profile on our GPU.
  environment.systemPackages = [ (hiPrio gamemoderunCustom) ];

  # So that apps like Steam can use our wrapped package. Not using a overlay to
  # avoid building apps with gamemode dep like PrismLauncher from source.
  ${ns}.programs.gaming.gamemode.customPackage = gamemoderunCustom;

  programs.gamemode = {
    enable = true;

    settings.custom = {
      # WARN: For gamemode script changes to be applied the user service must
      # be manually restarted with `systemctl restart --user gamemoded`
      start = getExe (startStopScript "start");
      end = getExe (startStopScript "end");
    };
  };
}
