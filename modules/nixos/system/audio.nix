{
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
    singleton
    ;
  cfg = config.modules.system.audio;

  toggleMic =
    let
      wpctl = getExe' pkgs.wireplumber "wpctl";
      notifySend = getExe pkgs.libnotify;
    in
    pkgs.writeShellScript "toggle-mic" ''
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
      modules.system.audio.scripts.toggleMic = toggleMic.outPath;

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
