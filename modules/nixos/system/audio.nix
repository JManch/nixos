{ lib
, pkgs
, config
, inputs
, username
, ...
}:
let
  cfg = config.modules.system.audio;
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
  gaming = config.modules.programs.gaming;

  toggleMic = pkgs.writeShellScript "toggle-mic" ''
    ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    status=$(${wpctl} get-volume @DEFAULT_AUDIO_SOURCE@)
    if [[ $status == *MUTED* ]]; then
      ${notifySend} -u critical -t 3000 "Microphone" "Muted"
    else
      ${notifySend} -u critical -t 3000 "Microphone" "Unmuted"
    fi
  '';
in
{
  imports = [
    inputs.nix-gaming.nixosModules.pipewireLowLatency
  ];

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        pkgs.pavucontrol
      ];
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        jack.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;
        lowLatency.enable = gaming.enable;
      };

      hardware.pulseaudio.enable = lib.mkForce false;

      # Make pipewire realtime-capable
      security.rtkit.enable = true;

      modules.system.audio.scripts.toggleMic = toggleMic.outPath;
    })

    (lib.mkIf (cfg.enable && cfg.extraAudioTools) {
      environment.systemPackages = with pkgs; [
        helvum
        qpwgraph
      ];

      environment.persistence."/persist".users.${username} = {
        directories = [
          ".config/rncbc.org"
          ".local/state/wireplumber"
          ".config/qpwgraph" # just for manually saved configs
        ];
      };
    })
  ];
}
