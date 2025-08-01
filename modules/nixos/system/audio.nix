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
    hiPrio
    ;
  inherit (config.${ns}.core) home-manager device;
  inherit (config.${ns}.system) desktop;
  inherit (config.${ns}.hardware) raspberry-pi;
  wpctl = getExe' pkgs.wireplumber "wpctl";
  pactl = getExe' pkgs.pulseaudio "pactl";
  notifySend = getExe pkgs.libnotify;
in
[
  {
    opts = {
      extraAudioTools = mkEnableOption "extra audio tools including Easyeffects and Helvum";
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

    ns.userPackages = mkIf desktop.enable [
      (lib.${ns}.wrapHyprlandMoveToActive args pkgs.pwvucontrol "com.saivert.pwvucontrol" "")
      (hiPrio (
        pkgs.runCommand "pwvucontrol-desktop-modify" { } ''
          mkdir -p $out/share/applications
          substitute ${pkgs.pwvucontrol}/share/applications/com.saivert.pwvucontrol.desktop $out/share/applications/com.saivert.pwvucontrol.desktop \
            --replace-fail "Name=pwvucontrol" "Name=Volume Control"
        ''
      ))

    ];

    services.pulseaudio.enable = mkForce false;

    # Make pipewire realtime-capable
    security.rtkit.enable = true;

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

        setup-pipewire-devices = {
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
            ExecStart = pkgs.writeShellScript "setup-pipewire-devices" ''
              sleep 2
              attempt=0
              while ! ${wpctl} inspect @DEFAULT_AUDIO_SINK@ &>/dev/null; do
                if (( attempt >= 30 )); then
                  echo "PipeWire failed to initialise in time"
                  exit 1
                fi

                echo "Waiting for PipeWire to initialise..."
                attempt=$((attempt + 1))
                sleep 2
              done

              ${optionalString (cfg.defaultSink != null) "${pactl} set-default-sink \"${cfg.defaultSink}\""}
              ${optionalString (cfg.defaultSource != null) "${pactl} set-default-source \"${cfg.defaultSource}\""}
              ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ ${if cfg.alwaysMuteSink then "1" else "0"}
              ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ 1
            '';
          };
          wantedBy = [ "graphical-session.target" ];
        };
      };
    };

    ns.hm =
      let
        inherit (config.${ns}.hmNs.desktop) hyprland;
        jaq = getExe pkgs.jaq;

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
            ${notifySend} -e -u critical -t 2000 \
              -h 'string:x-canonical-private-synchronous:pipewire-volume' 'Toggle Mute' "''${class^} device does not exist"
            exit 0
          fi

          ${wpctl} set-mute "$device" toggle
          status=$(${wpctl} get-volume "$device")
          message=$([[ $status == *MUTED* ]] && echo "Muted" || echo "Unmuted")
          if [[ $class == "SOURCE" ]]; then
            message="Microphone $message"
          fi
          description=$(echo "$inspect_data" | grep 'node\.description' | cut -d '"' -f 2)
          ${notifySend} -e -u critical -t 2000 \
            -h 'string:x-canonical-private-synchronous:pipewire-volume' "$description" "$message"
        '';

        modifyVolume = pkgs.writeShellScript "modify-volume" ''
          ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$1"
          output=$(${wpctl} get-volume @DEFAULT_AUDIO_SINK@)
          volume=$(echo "$output" | ${getExe pkgs.gawk} '{print $2}')
          percentage="$(echo "$volume * 100" | ${getExe pkgs.bc})"
          description=$(${wpctl} inspect @DEFAULT_AUDIO_SINK@ | grep 'node\.description' | cut -d '"' -f 2)
          notify-send --urgency=low -t 2000 \
            -h 'string:x-canonical-private-synchronous:pipewire-volume' "$description" "Volume ''${percentage%.*}%"
        '';

        modifyFocusedWindowVolume = pkgs.writeShellScript "hypr-modify-focused-window-volume" ''
          pid=$(${getExe' pkgs.hyprland "hyprctl"} activewindow -j | ${jaq} -r '.pid')
          node=$(${getExe' pkgs.pipewire "pw-dump"} | ${jaq} -r \
            "[.[] | select((.type == \"PipeWire:Interface:Node\") and (.info?.props?[\"application.process.id\"]? == "$pid"))] | sort_by(if .info?.state? == \"running\" then 0 else 1 end) | first")
          if [ "$node" == "null" ]; then
            ${notifySend} -e --urgency=critical -t 2000 \
              'Pipewire' "Active window does not have an interface node"
            exit 1
          fi

          id=$(echo "$node" | ${jaq} -r '.id')
          name=$(echo "$node" | ${jaq} -r '.info.props["application.name"]')
          media=$(echo "$node" | ${jaq} -r '.info.props["media.name"]')

          ${wpctl} set-volume "$id" "$1"
          output=$(${wpctl} get-volume "$id")
          volume=''${output#Volume: }
          percentage="$(echo "$volume * 100" | ${getExe pkgs.bc})"
          ${notifySend} -e --urgency=low -t 2000 \
            -h 'string:x-canonical-private-synchronous:pipewire-volume' "''${name^} - $media" "Volume ''${percentage%.*}%"
        '';
      in
      mkIf home-manager.enable {
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

          hyprland.settings = {
            windowrule = [
              "float, class:^(com\\.saivert\\.pwvucontrol)$"
              "size 60% 60%, class:^(com\\.saivert\\.pwvucontrol)$"
              "center, class:^(com\\.saivert\\.pwvucontrol)$"
            ];

            bind = [
              ", XF86AudioRaiseVolume, exec, ${modifyVolume} 5%+"
              ", XF86AudioLowerVolume, exec, ${modifyVolume} 5%-"
              ", XF86AudioMute, exec, ${toggleAudioMute} sink"
              ", XF86AudioMicMute, exec, ${toggleAudioMute} source"
              "${hyprland.modKey}SHIFTCONTROL, XF86AudioRaiseVolume, exec, ${modifyFocusedWindowVolume} 5%+"
              "${hyprland.modKey}SHIFTCONTROL, XF86AudioLowerVolume, exec, ${modifyFocusedWindowVolume} 5%-"
            ];

            bindr = [ "${hyprland.modKey}ALT, ALT_L, exec, ${toggleAudioMute} source" ];
          };
        };
      };

    ns.persistenceHome.directories = [ ".local/state/wireplumber" ];
  }

  (mkIf raspberry-pi.enable {
    # Don't know why but rtkit doesn't seem to work on raspberry pis so need
    # to add user to audio group for permissions
    security.rtkit.enable = mkForce false;
    users.users.${username}.extraGroups = [ "audio" ];
  })

  (mkIf cfg.extraAudioTools {
    ns.userPackages = with pkgs; [
      helvum
      qpwgraph
    ];

    ns.persistenceHome.directories = [
      ".config/rncbc.org"
      ".config/qpwgraph" # just for manually saved configs
    ];
  })
]
