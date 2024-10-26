{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkMerge
    mkIf
    getExe
    getExe'
    mkForce
    ;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.audio;
  wpctl = getExe' pkgs.wireplumber "wpctl";
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
      };

      # Do not start pipewire user sockets for non-system users. This prevents
      # pipewire sockets unnecessarily starting for the greeter user during
      # login.
      systemd.user.sockets = {
        pipewire.unitConfig.ConditionUser = "!@system";
        pipewire-pulse.unitConfig.ConditionUser = "!@system";
      };

      systemd.user.services.unmute-pipewire-devices = {
        description = "Unmute source and sink devices on login";
        after = [ "pipewire.service" ];
        wants = [ "pipewire.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "unmute-pipewire-devices" ''
            ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ 0
            ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ 0
          '';
        };
        wantedBy = [ "default.target" ];
      };

      hm = mkIf homeManager.enable {
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
