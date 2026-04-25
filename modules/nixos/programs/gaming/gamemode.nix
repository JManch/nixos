# GameMode is bloated and not necessary with good kernel schedulers. The only
# feature I was really using was the start/stop script. Gamemode also switches
# the power governer by default which I already do myself in lact and would
# rather control manually on laptops with TLP.

# This is my own "gamemode" implementation that:
# - Launches games in their own scope. This gives the game a dedicated cgroup
#   (normally the game ends up in the same cgroup as Steam which isn't ideal)
# - Gives the game resource priority over other applications in the graphical
#   desktop slice by setting the scope's CPUWeight property.
# - Runs a start/stop script from a simple "gamemode" user service that is
#   bound to whatever game activated it.
{
  lib,
  cfg,
  pkgs,
  config,
  username,
}:
let
  inherit (lib)
    ns
    mkOption
    mkBefore
    mkIf
    mkEnableOption
    types
    all
    hasAttr
    getExe
    getExe'
    boolToString
    mapAttrsToList
    optionalString
    concatLines
    ;
  inherit (lib.${ns})
    getMonitorHyprlandCfgStr
    isHyprland
    ;
  inherit (config.${ns}.core) home-manager;
  profiles = (config.${ns}.hmNs.programs.gaming.gamemode.profiles or { }) // cfg.profiles;

  gamemoderun = pkgs.writeShellApplication {
    name = "gamemoderun";
    runtimeInputs = with pkgs; [
      app2unit
      systemd
    ];
    # Have to write the profiles to a file so our gamemode service can read
    # them.

    # We can't write to /tmp because steam runs in a chroot with its own tmp
    # dir. Any files we write there will not be accessible from our gamemode
    # service. Our home directory is bind mounted in the chroot so that is
    # accessible.
    text = ''
      props=(-p CPUWeight=200)

      # Gamemode start/stop is only bound to the first game that activates it.
      if ! systemctl is-active --user --quiet gamemode.service; then
        props+=(-p Wants=gamemode.service -p PropagatesStopTo=gamemode.service)
        rm -f "/home/${username}/.gamemode-profiles"
        if [[ -n ''${GAMEMODE_PROFILES:-} ]]; then
          echo "$GAMEMODE_PROFILES" > "/home/${username}/.gamemode-profiles"
        fi
      fi

      exec app2unit \
        -a game \
        -t scope \
        "''${props[@]}" \
        -- "$@"

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
        if [[ -e $profiles_file ]]; then
          IFS=',' read -r -a profiles <<< "$(<"$profiles_file")"
        fi

        profile_exists() {
          local profile="$1"
          for elem in "''${profiles[@]}"; do
            if [[ $elem == "$profile" ]]; then
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

        message="${if mode == "stop" then "Stopped" else "Started"}"
        if (( ''${#profiles[@]} )); then
          message="$message with profile(s) $(IFS=', '; echo "''${profiles[*]}")"
        fi
        notify-send -e --urgency=critical -t 5000 'GameMode' "$message"
      '';
    };

in
{
  opts = {
    profiles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            includeDefaultProfile = mkEnableOption "the default profile scripts in this profile";

            start = mkOption {
              type = types.lines;
              default = "";
            };

            stop = mkOption {
              type = types.lines;
              default = "";
            };
          };
        }
      );
      default = { };
      description = ''
        Attribute set of Gamemode profiles with start/stop bash scripts.
        Gamemode profiles can be enabled by setting the GAMEMODE_PROFILES
        environment variable to a comma separated list of profile names.
      '';
    };
  };

  asserts = [
    (all (v: v == false) (
      mapAttrsToList (
        profile: _: hasAttr profile (config.${ns}.hmNs.programs.gaming.gamemode.profiles or { })
      ) cfg.profiles
    ))
    "Home manager and NixOS must not define the same gamemode profiles"
  ];

  ns.userPackages = [ gamemoderun ];

  ns.programs.gaming.gamemode.profiles."default" =
    let
      inherit (config.${ns}.hmNs.desktop) hyprland;
      inherit (config.${ns}.core.device) primaryMonitor;
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
          keyword render:direct_scanout ${if hyprland.directScanout then "1" else "0"}; \
        "
      '';

      stop = optionalString (isHyprland config) ''
        ${hyprctl} --instance 0 --batch "\
          keyword monitor ${getMonitorHyprlandCfgStr primaryMonitor}; \
          ${killActiveRebind false}; \
          keyword decoration:blur:enabled ${boolToString hyprland.blur}; \
          keyword render:direct_scanout 0; \
        "
      '';
    };

  systemd.user.services."gamemode" = {
    path = lib.mkForce [ ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = getExe (startStopScript "start");
      ExecStop = getExe (startStopScript "stop");
    };
  };

  ns.hm = mkIf home-manager.enable {
    programs.waybar.settings.bar = {
      modules-right = mkBefore [ "custom/gamemode" ];
      "custom/gamemode" = {
        format = "<span color='#${config.${ns}.hm.colorScheme.palette.base04}'>󰊴 </span> {}";
        exec = ''systemctl is-active --quiet --user inhibit-lock && echo -n "GameMode" || echo -n ""'';
        interval = 30;
        tooltip = false;
        on-click-right = "systemctl stop --user gamemode";
      };
    };
  };
}
