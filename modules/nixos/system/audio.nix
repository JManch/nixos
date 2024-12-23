{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    mkMerge
    mkIf
    getExe
    getExe'
    mkForce
    singleton
    optionalString
    mapAttrsToList
    ;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.audio;
  wpctl = getExe' pkgs.wireplumber "wpctl";
  pactl = getExe' pkgs.pulseaudio "pactl";
  notifySend = getExe pkgs.libnotify;

  toggleMic = pkgs.writeShellScript "toggle-mic" ''
    ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    status=$(${wpctl} get-volume @DEFAULT_AUDIO_SOURCE@)
    message=$([[ "$status" == *MUTED* ]] && echo "Muted" || echo "Unmuted")
    ${notifySend} -u critical -t 2000 \
      -h 'string:x-canonical-private-synchronous:microphone-toggle' 'Microphone' "$message"
  '';
in
{
  config = mkMerge [
    (mkIf cfg.enable {
      userPackages = [ pkgs.pavucontrol ];
      hardware.pulseaudio.enable = mkForce false;
      ${ns}.system.audio.scripts.toggleMic = toggleMic.outPath;

      # Make pipewire realtime-capable
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        jack.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;

        wireplumber.extraConfig = mkIf (cfg.alsaDeviceAliases != { }) {
          "99-alsa-device-aliases"."monitor.alsa.rules" = mapAttrsToList (old: new: {
            matches = singleton {
              "node.name" = old;
            };
            actions.update-props."node.description" = new;
          }) cfg.alsaDeviceAliases;
        };
      };

      # Do not start pipewire user sockets or services for non-system users.
      # This prevents pipewire unnecessarily starting for the greeter user
      # during login.
      systemd.user = {
        sockets = {
          pipewire.unitConfig.ConditionUser = "!@system";
          pipewire-pulse.unitConfig.ConditionUser = "!@system";
        };
        services = {
          pipewire.unitConfig.ConditionUser = "!@system";
          wireplumber.unitConfig.ConditionUser = "!@system";
          pipewire-pulse.unitConfig.ConditionUser = "!@system";
        };
      };

      systemd.user.services.setup-pipewire-devices = {
        description = "Setup source and sink devices on login";
        after = [ "wireplumber.service" ];
        wants = [ "wireplumber.service" ];
        unitConfig.ConditionUser = "!@system";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "setup-pipewire-devices" ''
            sleep 2
            attempt=0
            while ! ${wpctl} inspect @DEFAULT_AUDIO_SINK@ &>/dev/null; do
              if (( attempt >= 10 )); then
                echo "PipeWire failed to initialise in time"
                exit 1
              fi

              echo "Waiting for PipeWire to initialise..."
              ((attempt++))
              sleep 2
            done

            ${optionalString (cfg.defaultSink != null) "${pactl} set-default-sink \"${cfg.defaultSink}\""}
            ${optionalString (cfg.defaultSource != null) "${pactl} set-default-source \"${cfg.defaultSource}\""}
            ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0
            ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ 1
          '';
        };
        wantedBy = [ "default.target" ];
      };

      hm = mkIf homeManager.enable {
        ${ns}.desktop.programs.locking = {
          preLockScript = ''
            ${pactl} get-sink-mute @DEFAULT_SINK@ > /tmp/lock-mute-sink
            ${pactl} get-source-mute @DEFAULT_SOURCE@ > /tmp/lock-mute-source
            ${pactl} set-sink-mute @DEFAULT_SINK@ 1
            ${pactl} set-source-mute @DEFAULT_SOURCE@ 1
          '';

          postUnlockScript = ''
            if [[ -f /tmp/lock-mute-sink ]] && grep -q "no" /tmp/lock-mute-sink; then
              ${pactl} set-sink-mute @DEFAULT_SINK@ 0
            fi

            if [[ -f /tmp/lock-mute-source ]] && grep -q "no" /tmp/lock-mute-source; then
              ${pactl} set-source-mute @DEFAULT_SOURCE@ 0
            fi
            rm -f /tmp/lock-mute-{sink,source}
          '';
        };

        desktop.hyprland.settings.windowrulev2 = [
          "float, class:^(org.pulseaudio.pavucontrol)$"
          "size 50% 50%, class:^(org.pulseaudio.pavucontrol)$"
          "center, class:^(org.pulseaudio.pavucontrol)$"
        ];
      };
    })

    (mkIf (cfg.enable && cfg.extraAudioTools) {
      userPackages = with pkgs; [
        helvum
        qpwgraph
      ];

      persistenceHome.directories = [
        ".config/rncbc.org"
        ".local/state/wireplumber"
        ".config/qpwgraph" # just for manually saved configs
      ];
    })
  ];
}
