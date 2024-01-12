{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let cfg = config.modules.programs.mpv;
in
lib.mkIf cfg.enable {
  home.packages = [
    pkgs.yt-dlp
    pkgs.streamlink
  ];

  programs.mpv = {
    enable = true;
    config = {
      profile = "gpu-hq";
      ytdl-format = "bestvideo+bestaudio";
      hwdec = "auto";
    };
    bindings = {
      WHEEL_UP = "add volume 5";
      WHEEL_DOWN = "add volume -5";
      "Ctrl+WHEEL_UP" = "add speed 0.1";
      "Ctrl+WHEEL_DOWN" = "add speed -0.1";
      "MBTN_MID" = "cycle mute";
      F1 = "af toggle acompressor=ratio=4; af toggle loudnorm";
    };
  };

  xdg.configFile."streamlink/config".text = ''
    player=mpv
    player-args=--loop-playlist=inf --loop-file=inf --cache=yes --demuxer-max-back-bytes=1073741824
  '';

  xdg.configFile."streamlink/config.twitch".text = ''
    twitch-low-latency
    twitch-disable-ads
  '';
}
