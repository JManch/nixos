{
  lib,
  cfg,
  args,
  pkgs,
  config,
  username,
}:
let
  inherit (lib)
    ns
    mkMerge
    mkIf
    getExe
    getExe'
    mkEnableOption
    types
    mkOption
    mkForce
    singleton
    optionalString
    mapAttrsToList
    optional
    optionals
    hiPrio
    ;
  inherit (lib.${ns})
    wrapHyprlandMoveToActive
    mkHyprlandCenterFloatRule
    throttleHyprlandRepeatBind
    mkHyprBind
    mkHyprExec
    ;
  inherit (config.${ns}.core) home-manager device;
  inherit (config.${ns}.system) desktop;
  inherit (config.${ns}.hardware) raspberry-pi;
  wpctl = getExe' pkgs.wireplumber "wpctl";
  pactl = getExe' pkgs.pulseaudio "pactl";
  notify-send = getExe pkgs.libnotify;
in
[
  {
    opts = {
      inputNoiseSuppression = mkEnableOption "input noise suppression source";

      alwaysMuteSink = mkOption {
        type = types.bool;
        default = device.type == "laptop";
        description = ''
          Muting the default sink when powering up the system and when resuming
          from sleep state. We mute in our "setup-pipewire-devices" service and
          in our locker unlock script.
        '';
      };

      alsaDeviceAliases = mkOption {
        type = with types; attrsOf str;
        default = { };
        description = ''
          Attribute set of alsa devices to rename where the name is the
          original name and the value is the new name. The original name can be
          found using `pamixer --list-sinks` or `pamixer --list-sources`.
        '';
      };

      defaultSink = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "System default audio sink name from `pactl list short sinks`";
      };

      defaultSource = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "System default audio source name from `pactl list short sources`";
      };
    };

    asserts = [
      (cfg.alwaysMuteSink -> desktop.desktopEnvironment == null)
      "Always mute sink does not work with a desktop environment"
      (cfg.defaultSink != null -> desktop.desktopEnvironment == null)
      "Default sink does not work with a desktop environment"
      (cfg.defaultSource != null -> desktop.desktopEnvironment == null)
      "Default source does not work with a desktop environment"
    ];

    ns.userPackages = mkIf desktop.enable (
      optionals (desktop.desktopEnvironment == null) [
        (wrapHyprlandMoveToActive args pkgs.pwvucontrol "com.saivert.pwvucontrol" "")
        (hiPrio (
          pkgs.runCommand "pwvucontrol-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.pwvucontrol}/share/applications/com.saivert.pwvucontrol.desktop $out/share/applications/com.saivert.pwvucontrol.desktop \
              --replace-fail "Name=pwvucontrol" "Name=Volume Control"
          ''
        ))
        # Also installing pavucontrol because I've had multiple instances where
        # pwvucontrol is unable to change the volume of devices. The UI changes
        # but the volume change is not applied. Think it's something to do with
        # the active profile. Also the project is in a bit of an uncertain state
        # at the moment:
        # https://github.com/saivert/pwvucontrol/issues/10
        (wrapHyprlandMoveToActive args pkgs.pavucontrol "org.pulseaudio.pavucontrol" "")
        (hiPrio (
          pkgs.runCommand "pavucontrol-desktop-modify" { } ''
            mkdir -p $out/share/applications
            substitute ${pkgs.pavucontrol}/share/applications/org.pulseaudio.pavucontrol.desktop $out/share/applications/org.pulseaudio.pavucontrol.desktop \
              --replace-fail "Name=Volume Control" "Name=Pavucontrol"
          ''
        ))
      ]
      ++ [
        pkgs.qpwgraph
      ]
    );

    services.pulseaudio.enable = mkForce false;

    # Instead of using rtkit, adding our user to the pipewire group gives our
    # user a ulimit of 95 [1] which enables pipewire to acquire priority
    # itself. According to [2], it sounds like this is actually preferrable to
    # using rtkit.

    # Our user having ulimit 95 has the added benefit of Hyprland being able
    # acquire a RR scheduling policy [3]. Might eventually be solved with a
    # security wrapper? [4]
    # [1] https://github.com/NixOS/nixpkgs/blob/68d8aa3d661f0e6bd5862291b5bb263b2a6595c9/nixos/modules/services/desktops/pipewire/pipewire.nix#L428
    # [2] https://gitlab.freedesktop.org/pipewire/pipewire/-/commit/b4be094be8d9367c559692aac4d39d19f0c47b73
    # [3] https://github.com/hyprwm/Hyprland/blob/fb46d16fc2bedea96b6b2a4d005ec66d701431aa/src/init/initHelpers.cpp#L8
    # [4] https://github.com/NixOS/nixpkgs/pull/507419
    security.rtkit.enable = false;
    users.users.${username}.extraGroups = [ "pipewire" ];

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;

      wireplumber.extraConfig = mkMerge [
        {
          "99-disable-restore-props"."stream.rules" = singleton {
            matches = [
              # A lot of different applications fall under the "mpv" audio application so
              # always having the audio level get restored can be pretty annoying. Also we
              # should prefer adjusting soft volume over ao-volume.
              { "application.name" = "mpv"; }
              # Some Music apps (e.g. Spotify) adjust application audio level whilst others
              # (e.g. supersonic) adjust the soft audio level inside MPV. We want the
              # application audio level of apps like supersonic to always stay at 100 rather
              # than syncing with apps like Spotify. Doesn't seem to have any downsides since
              # Spotify remembers its own audio level.
              { "media.role" = "Music"; }
              # Would rather have Movie apps restore their own volume instead of grouping
              { "media.role" = "Movie"; }
            ];
            # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html
            actions.update-props."state.restore-props" = false;
          };
        }

        (mkIf (cfg.alsaDeviceAliases != { }) {
          "99-alsa-device-aliases"."monitor.alsa.rules" = mapAttrsToList (old: new: {
            matches = singleton {
              "node.name" = old;
            };
            actions.update-props."node.description" = new;
          }) cfg.alsaDeviceAliases;
        })
      ];

      extraConfig.pipewire."99-input-denoising.conf" = mkIf cfg.inputNoiseSuppression {
        "context.modules" = singleton {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Noise Canceling source";
            "media.name" = "Noise Canceling source";
            "filter.graph" = {
              nodes = singleton {
                type = "ladspa";
                name = "rnnoise";
                plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                label = "noise_suppressor_mono";
                control = {
                  "VAD Threshold (%)" = 50.0;
                  "VAD Grace Period (ms)" = 200;
                  "Retroactive VAD Grace (ms)" = 0;
                };
              };
            };
            "capture.props" = {
              "node.name" = "capture.rnnoise_source";
              "node.passive" = true;
              "audio.rate" = 48000;
            };
            "playback.props" = {
              "node.name" = "rnnoise_source";
              "media.class" = "Audio/Source";
              "audio.rate" = 48000;
            };
          };
        };
      };
    };

    # On Nix systemd user services are enabled for all users by default.
    # Pretty much all of the units in /etc/systemd/user/*.wants/* should have
    # ConditionUser !@system since these services should never be ran as
    # root. Services that wants graphical-session.target shouldn't need this
    # since root shouldn't start graphical sessions.
    # https://github.com/NixOS/nixpkgs/issues/21460
    systemd.user = {
      sockets = {
        pipewire.unitConfig.ConditionUser = "!@system";
        pipewire-pulse.unitConfig.ConditionUser = "!@system";
      };
      services = {
        pipewire.unitConfig.ConditionUser = "!@system";
        wireplumber.unitConfig.ConditionUser = "!@system";
        pipewire-pulse.unitConfig.ConditionUser = "!@system";

        setup-pipewire-devices = mkIf (desktop.desktopEnvironment == null) {
          description = "Setup Pipewire devices on login";
          after = [
            "wireplumber.service"
            "graphical-session.target"
          ];
          requires = [ "wireplumber.service" ];
          partOf = [ "graphical-session.target" ];
          unitConfig.ConditionUser = "!@system";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = getExe (
              pkgs.writeShellApplication {
                name = "setup-pipewire-devices";
                runtimeInputs = with pkgs; [
                  coreutils
                  wireplumber
                  pulseaudio
                  gnugrep
                ];
                bashOptions = [
                  "nounset"
                  "pipefail"
                ];
                text = ''
                  sleep 2
                  attempt=0
                  while ! wpctl inspect @DEFAULT_AUDIO_SINK@ &>/dev/null; do
                    if (( attempt >= 30 )); then
                      echo "PipeWire failed to initialise in time"
                      exit 1
                    fi

                    echo "Waiting for PipeWire to initialise..."
                    attempt=$((attempt + 1))
                    sleep 2
                  done

                  ${optionalString (cfg.defaultSink != null) "pactl set-default-sink \"${cfg.defaultSink}\""}
                  ${optionalString (cfg.defaultSource != null) "pactl set-default-source \"${cfg.defaultSource}\""}
                  wpctl set-mute @DEFAULT_AUDIO_SINK@ ${if cfg.alwaysMuteSink then "1" else "0"}
                  # @DEFAULT_AUDIO_SOURCE@ can resolve to a sink if no sources exist
                  # https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/509
                  if [[ $(wpctl inspect @DEFAULT_AUDIO_SOURCE@ | grep 'media\.class' | cut -d '"' -f 2) == "Audio/Source" ]]; then
                    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1
                  fi
                '';
              }
            );
          };
          wantedBy = [ "graphical-session.target" ];
        };

        # Monitors the PipeWire/PulseAudio event socket and emits volume and
        # mute notifications for the default sink and source.
        audio-notifications = mkIf (home-manager.enable && desktop.desktopEnvironment == null) {
          description = "Audio notification monitor";
          after = [
            "wireplumber.service"
            "graphical-session.target"
          ];
          requires = [ "wireplumber.service" ];
          requisite = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          unitConfig.ConditionUser = "!@system";
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 2;
            ExecStart = getExe (
              pkgs.writeShellApplication {
                name = "audio-notifications";
                runtimeInputs = with pkgs; [
                  coreutils
                  pulseaudio
                  wireplumber
                  libnotify
                  gnugrep
                  gawk
                  bc
                ];
                bashOptions = [
                  "nounset"
                  "pipefail"
                ];
                text = ''
                  notify() {
                    notify-send --transient -u "$1" -t 2000 \
                      -h 'string:x-canonical-private-synchronous:pipewire-volume' "$2" "$3"
                  }

                  prev_sink_vol=""
                  prev_sink_mute=""
                  prev_source_mute=""

                  handle_sink() {
                    local output mute volume percentage vol description
                    output=$(wpctl get-volume @DEFAULT_AUDIO_SINK@) || return
                    if [[ $output == *MUTED* ]]; then mute="yes"; else mute="no"; fi
                    volume=$(awk '{print $2}' <<< "$output")
                    percentage=$(bc <<< "$volume * 100")
                    vol="''${percentage%.*}"

                    # The event was for a different sink so do nothing
                    if [[ $mute == "$prev_sink_mute" && $vol == "$prev_sink_vol" ]]; then
                      return
                    fi

                    description=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | grep 'node\.description' | cut -d '"' -f 2)

                    if [[ $mute != "$prev_sink_mute" ]]; then
                      if [[ $mute == "yes" ]]; then
                        [[ -n $quiet ]] || notify critical "$description" "Muted"
                      else
                        [[ -n $quiet ]] || notify critical "$description" "Unmuted"
                      fi
                    else
                      [[ -n $quiet ]] || notify low "$description" "Volume $vol%"
                    fi

                    prev_sink_mute="$mute"
                    prev_sink_vol="$vol"
                  }

                  handle_source() {
                    local inspect_data class output mute description
                    inspect_data=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@) || return
                    # @DEFAULT_AUDIO_SOURCE@ can resolve to a sink if no sources exist
                    # https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/509
                    class=$(grep 'media\.class' <<< "$inspect_data" | cut -d '"' -f 2)
                    [[ $class == "Audio/Source" ]] || return

                    output=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@) || return
                    if [[ $output == *MUTED* ]]; then mute="yes"; else mute="no"; fi
                    [[ $mute == "$prev_source_mute" ]] && return

                    description=$(grep 'node\.description' <<< "$inspect_data" | cut -d '"' -f 2)
                    if [[ $mute == "yes" ]]; then
                      [[ -n $quiet ]] || notify critical "$description" "Microphone Muted"
                    else
                      [[ -n $quiet ]] || notify critical "$description" "Microphone Unmuted"
                    fi
                    prev_source_mute="$mute"
                  }

                  quiet="1"
                  handle_sink
                  handle_source
                  quiet=""

                  pactl subscribe | while read -r line; do
                    case "$line" in
                      *"'change' on sink #"*) handle_sink ;;
                      *"'change' on source #"*) handle_source ;;
                    esac
                  done
                '';
              }
            );
          };
          wantedBy = [ "graphical-session.target" ];
        };
      };
    };

    ns.hm =
      let
        toggleAudioMute = pkgs.writeShellScript "toggle-audio-mute" ''
          class=$1
          if [[ $class != "source" && $class != "sink" ]]; then
            echo "Invalid device class: '$class'. Must be 'source' or 'sink'." >&2
            exit 1
          fi
          device="@DEFAULT_AUDIO_''${class^^}@"
          inspect_data=$(${wpctl} inspect "$device")

          # @DEFAULT_AUDIO_SOURCE@ can resolve to a sink if no sources exist
          # https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/509
          if [[ "Audio/''${class^}" != $(echo "$inspect_data" | grep 'media\.class' | cut -d '"' -f 2) ]]; then
            ${notify-send} --transient -u critical -t 2000 \
              -h 'string:x-canonical-private-synchronous:pipewire-volume' 'Toggle Mute' "''${class^} device does not exist"
            exit 0
          fi

          ${wpctl} set-mute "$device" toggle
        '';

        modifyVolume = pkgs.writeShellScript "modify-volume" ''
          ${throttleHyprlandRepeatBind "volume" 10}
          ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$1"
        '';
      in
      mkIf (home-manager.enable && desktop.desktopEnvironment == null) {
        dconf.settings."com/saivert/pwvucontrol".enable-overamplification = true;
        programs.waybar.settings.bar = {
          "wireplumber#sink".on-click-right = "${toggleAudioMute} sink";
          "wireplumber#source".on-click = "${toggleAudioMute} source";
        };

        ${ns}.desktop = {
          programs.locker = {
            preLockScript = ''
              ${pactl} get-sink-mute @DEFAULT_SINK@ > /tmp/lock-mute-sink
              ${pactl} get-source-mute @DEFAULT_SOURCE@ > /tmp/lock-mute-source
              ${pactl} set-sink-mute @DEFAULT_SINK@ 1
              ${pactl} set-source-mute @DEFAULT_SOURCE@ 1
            '';

            postUnlockScript = ''
              ${
                if cfg.alwaysMuteSink then
                  "${pactl} set-sink-mute @DEFAULT_SINK@ 1"
                else
                  # bash
                  ''
                    if [[ -f /tmp/lock-mute-sink ]] && grep -q "no" /tmp/lock-mute-sink; then
                      ${pactl} set-sink-mute @DEFAULT_SINK@ 0
                    fi
                  ''
              }

              if [[ -f /tmp/lock-mute-source ]] && grep -q "no" /tmp/lock-mute-source; then
                ${pactl} set-source-mute @DEFAULT_SOURCE@ 0
              fi
              rm -f /tmp/lock-mute-{sink,source}
            '';
          };

          hyprland.windowRules = {
            pwvucontrol = mkHyprlandCenterFloatRule "com\\.saivert\\.pwvucontrol" 60 60;
            pavucontrol = mkHyprlandCenterFloatRule "org\\.pulseaudio\\.pavucontrol" 60 60;
          };

          hyprland.binds = [
            (mkHyprBind "" "XF86AudioRaiseVolume"
              ''hl.dsp.exec_cmd("${modifyVolume} 5%+"), { repeating = true }''
            )
            (mkHyprBind "" "XF86AudioLowerVolume"
              ''hl.dsp.exec_cmd("${modifyVolume} 5%-"), { repeating = true }''
            )

            (mkHyprExec "" "XF86AudioMute" "${toggleAudioMute} sink")
            (mkHyprExec "" "XF86AudioMicMute" "${toggleAudioMute} source")

            (mkHyprBind "mod" "ALT + ALT_L"
              ''hl.dsp.exec_cmd("${toggleAudioMute} source"), { release = true }''
            )
          ];
        };
      };

    ns.persistenceHome.directories = [
      ".local/state/wireplumber"
    ]
    ++ optional desktop.enable ".config/qpwgraph";
  }

  (mkIf raspberry-pi.enable {
    # Don't know why but rtkit doesn't seem to work on raspberry pis so need
    # to add user to audio group for permissions
    security.rtkit.enable = mkForce false;
    users.users.${username}.extraGroups = [ "audio" ];
  })
]
