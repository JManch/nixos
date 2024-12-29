{
  lib,
  pkgs,
  config,
  username,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    all
    hasAttr
    getExe
    getExe'
    hiPrio
    escapeShellArg
    boolToString
    mapAttrsToList
    optionalString
    concatLines
    ;
  inherit (lib.${ns})
    asserts
    upperFirstChar
    getMonitorHyprlandCfgStr
    isHyprland
    ;
  inherit (config.${ns}.system) desktop;
  cfg = config.${ns}.programs.gaming.gamemode;
  profiles = (config.hm.${ns}.programs.gaming.gamemode.profiles or { }) // cfg.profiles;

  gamemodeWrapped = pkgs.symlinkJoin {
    name = "gamemode-wrapped-profiles";
    paths = [ pkgs.gamemode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # Have to write the profiles to a file so that the gamemode start script
      # can read them from the file. I'm not aware of any other way to pass
      # custom arguments to the start script (and it does not inherit env vars)

      # We can't write to /tmp because steam runs in a chroot with its own
      # tmp dir. Any files we write there will not be accessible from our
      # gamemoderun start script. Our home directory is bind mounted in the
      # chroot so that is accessible.
      wrapProgram $out/bin/gamemoderun --run '
        if [ -e "/home/${username}/.gamemode-profiles" ]; then
          ${getExe pkgs.libnotify} --urgency=critical -t 5000 "GameMode" "Profiles file already exists"
          exit 1
        fi
        echo "$GAMEMODE_PROFILES" > "/home/${username}/.gamemode-profiles"
      '
    '';
  };

  startStopScript =
    mode:
    pkgs.writeShellApplication {
      name = "gamemode-${mode}";
      runtimeInputs = with pkgs; [
        coreutils
        libnotify
      ];
      text = ''
        # Load custom arguments from file that our wrapper wrote to
        profiles_file="/home/${username}/.gamemode-profiles"
        profiles=()
        if [ -e "$profiles_file" ]; then
          IFS=',' read -r -a profiles <<< "$(<"$profiles_file")"
          ${optionalString (mode == "stop") "rm \"$profiles_file\""}
        else
          notify-send --urgency=critical -t 5000 \
            'GameMode' '${upperFirstChar mode} script args file missing'
          exit 1
        fi

        profile_exists() {
          local profile="$1"
          for elem in "''${profiles[@]}"; do
            if [[ "$elem" == "$profile" ]]; then
              return 0
            fi
          done
          return 1
        }

        # If no custom args were provided, load the default profile
        if (( ! ''${#profiles[@]} )); then
          : # to avoid empty if statement
          ${profiles.default.${mode}}
        fi

        # Load a profile if its name is one of the args
        ${concatLines (
          mapAttrsToList (
            profile: cfg': # bash
            ''
              if profile_exists "${profile}"; then
                : # to avoid empty if statement
                ${optionalString cfg'.includeDefaultProfile profiles.default.${mode}}
                ${cfg'.${mode}}
              fi
            '') profiles
        )}

        ${optionalString (desktop.desktopEnvironment == null) # bash
          ''
            message="${if mode == "stop" then "Stopped" else "Started"}"
            if (( ''${#profiles[@]} )); then
              message="$message with profile(s) $(IFS=', '; echo "''${profiles[*]}")"
            fi
            notify-send --urgency=critical -t 5000 'GameMode' "$message"
          ''
        }
      '';
    };

in
mkIf cfg.enable {
  assertions = asserts [
    (all (v: v == false) (
      mapAttrsToList (
        profile: _: hasAttr profile (config.hm.${ns}.programs.gaming.gamemode.profiles or { })
      ) cfg.profiles
    ))
    "Home manager and NixOS must not define the same gamemode profiles"
  ];

  # Do not start gamemoded for system users. This prevents gamemoded starting
  # during login when greetd temporarily runs as the greeter user.
  systemd.user.services.gamemoded.unitConfig.ConditionUser = "!@system";

  # Since version 1.8 gamemode requires the user to be in the gamemode group
  # https://github.com/FeralInteractive/gamemode/issues/452
  users.users.${username}.extraGroups = [ "gamemode" ];

  # This allows us to pass a comma seperated list of profiles to gamemode start
  # and stop scripts with the GAMEMODE_PROFILES env var. For example, setting
  # GAMEMODE_PROFILES=vr sets a higher GPU power cap in our start script and
  # enables the VR profile on our GPU.
  environment.systemPackages = [ (hiPrio gamemodeWrapped) ];

  ${ns}.programs.gaming.gamemode = {
    wrappedPackage = gamemodeWrapped;
    profiles.default =
      let
        inherit (config.hm.${ns}.desktop) hyprland;
        inherit (config.${ns}.device) primaryMonitor;
        hyprctl = getExe' pkgs.hyprland "hyprctl";

        # Remap the killactive key to use the shift modifier
        killActiveRebind = isStart: ''
          keyword unbind ${hyprland.modKey}${optionalString (!isStart) "SHIFTCONTROL"}, W; \
          keyword bind ${hyprland.modKey}${optionalString isStart "SHIFTCONTROL"}, W, killactive'';
      in
      {
        start = optionalString (isHyprland config) ''
          ${hyprctl} --instance 0 --batch "\
            keyword monitor ${
              getMonitorHyprlandCfgStr (primaryMonitor // { refreshRate = primaryMonitor.gamingRefreshRate; })
            }; \
            ${killActiveRebind true}; \
            keyword decoration:blur:enabled false; \
          "
        '';

        stop = optionalString (isHyprland config) ''
          ${hyprctl} --instance 0 --batch "\
            keyword monitor ${getMonitorHyprlandCfgStr primaryMonitor}; \
            ${killActiveRebind false}; \
            keyword decoration:blur:enabled ${boolToString hyprland.blur}; \
          "
        '';
      };
  };

  programs.gamemode = {
    enable = true;

    settings.custom = {
      # WARN: For gamemode script changes to be applied the user service must
      # be manually restarted with `systemctl restart --user gamemoded`
      start = getExe (startStopScript "start");
      end = getExe (startStopScript "stop");
    };
  };
}
