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

  ns.desktop.hyprland.settings =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;
    in
    {
      bindr = [
        "${modKey}, ${modKey}_R, exec, ${playerctl} play-pause --player ${musicPlayers}"
        "${modKey}SHIFT, ${modKey}_R, exec, ${playerctl} play-pause --ignore-player ${musicPlayers}"
      ];

      bind = [
        "${modKey}, Period, exec, ${playerctl} next --player ${musicPlayers}"
        "${modKey}, Comma, exec, ${playerctl} previous --player ${musicPlayers}"
        ", XF86AudioNext, exec, ${playerctl} next"
        ", XF86AudioPrev, exec, ${playerctl} previous"
        ", XF86AudioPlay, exec, ${playerctl} play-pause"
        ", XF86AudioPause, exec, ${playerctl} pause"
      ];

      binde = [
        "${modKey}, XF86AudioRaiseVolume, exec, ${getExe (modifyPlayerVolume true)} 5"
        "${modKey}, XF86AudioLowerVolume, exec, ${getExe (modifyPlayerVolume true)} -5"
        "${modKey}SHIFT, XF86AudioRaiseVolume, exec, ${getExe (modifyPlayerVolume false)} 5"
        "${modKey}SHIFT, XF86AudioLowerVolume, exec, ${getExe (modifyPlayerVolume false)} -5"
      ];
    };
}
