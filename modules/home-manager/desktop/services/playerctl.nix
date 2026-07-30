{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkOption
    types
    concatStringsSep
    getExe
    toSentenceCase
    ;
  inherit (lib.${ns}) mkHyprBind mkHyprExec;
  inherit (cfg) musicPlayers;
  playerctl = getExe pkgs.playerctl;

  modifyPlayerVolume =
    isMusic:
    let
      name = if isMusic then "music" else "media";
      upperName = toSentenceCase name;
      arg = if isMusic then "--player ${musicPlayers}" else "--ignore-player ${musicPlayers}";
    in
    pkgs.writeShellApplication {
      name = "modify-${name}-volume";
      runtimeInputs =
        (with pkgs; [
          libnotify
          gawk
          bc
        ])
        ++ [ pkgs.playerctl ];
      text = ''
        increment=$1
        set +e
        if ! current_vol=$(playerctl volume ${arg}); then
          notify-send --urgency=critical -t 2000 \
            -h 'string:x-canonical-private-synchronous:playerctl-${name}-volume' '${upperName}' 'No ${name} player running'
          exit 1
        fi
        set -e

        round_volume() {
          multiple=''${increment#-}
          add_half=$(bc <<< "scale=10; ($1 + $multiple/2)")
          rounded=$(bc <<< "($add_half / $multiple) * $multiple")
          bc <<< "scale=2; $rounded / 100"
        }

        current_vol=$(echo "$current_vol" | awk '{print int($1 * 100)}')
        new_vol=$(round_volume $((current_vol + increment)))

        playerctl volume "$new_vol" ${arg}
        actual_vol=$(playerctl volume ${arg} | awk '{print int($1 * 100)}')
        notify-send --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:playerctl-${name}-volume' '${upperName}' "Volume ''${actual_vol%.*}%"
      '';
    };
in
{
  enableOpt = false;
  conditions = [
    "osConfig.system.audio"
    (cfg.musicPlayers != [ ])
  ];

  opts.musicPlayers = mkOption {
    type = with types; listOf str;
    default = [ ];
    apply = concatStringsSep ",";
    description = ''
      List of music players as shown in `playerctl --list-all`. Order
      determines priority.
    '';
  };

  services.playerctld.enable = true;

  ns.desktop = {
    programs.locker.postLockScript = ''
      (sleep 30 && playerctl --all-players pause) &
    '';

    hyprland.binds = [
      (mkHyprExec "mod" "Period" "${playerctl} next --player ${musicPlayers}")
      (mkHyprExec "mod" "Comma" "${playerctl} previous --player ${musicPlayers}")
      (mkHyprExec "" "XF86AudioNext" "${playerctl} next")
      (mkHyprExec "" "XF86AudioPrev" "${playerctl} previous")
      (mkHyprExec "" "XF86AudioPlay" "${playerctl} play-pause")
      (mkHyprExec "" "XF86AudioPause" "${playerctl} pause")
      (mkHyprBind "mod" "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("${getExe (modifyPlayerVolume true)} 5"), { repeating = true }'')
      (mkHyprBind "mod" "XF86AudioLowerVolume" ''hl.dsp.exec_cmd("${getExe (modifyPlayerVolume true)} -5"), { repeating = true }'')
      (mkHyprBind "mod_shift" "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("${getExe (modifyPlayerVolume false)} 5"), { repeating = true }'')
      (mkHyprBind "mod_shift" "XF86AudioLowerVolume" ''hl.dsp.exec_cmd("${getExe (modifyPlayerVolume false)} -5"), { repeating = true }'')
    ];

    hyprland.extraConf = # lua
      ''
        hl.bind(mod .. " + " .. mod .. "_R", hl.dsp.exec_cmd("${playerctl} play-pause --player ${musicPlayers}"), { release = true })
        hl.bind(mod_shift .. " + " .. mod .. "_R", hl.dsp.exec_cmd("${playerctl} play-pause --ignore-player ${musicPlayers}"), { release = true })
      '';
  };
}
