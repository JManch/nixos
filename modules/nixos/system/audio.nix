{ pkgs
, username
, lib
, config
, ...
}:
let
  cfg = config.modules.system.audio;
in
lib.mkMerge [

  (lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pkgs.pavucontrol
      pkgs.pulseaudio # installing just for the pactl cli tool
    ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    hardware.pulseaudio.enable = lib.mkForce false;

    # Reduces latency in some situations
    security.rtkit.enable = true;
  })

  (lib.mkIf (cfg.enable && cfg.extraAudioTools) {
    environment.systemPackages = with pkgs; [
      helvum
      qpwgraph
    ];

    environment.persistence."/persist".users.${username} = {
      directories = [
        ".config/rncbc.org"
      ];
    };
  })
]
