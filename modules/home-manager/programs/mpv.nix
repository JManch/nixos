{ lib
, pkgs
, config
, outputs
, ...
}:
let
  cfg = config.modules.programs.mpv;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.yt-dlp ];

  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      thumbfast
      sponsorblock-minimal
      outputs.packages.${pkgs.system}.modernx
    ];
    scriptOpts = {
      modernx = {
        scalewindowed = 1;
        scalefullscreen = 1;
        fadeduration = 150;
        hidetimeout = 5000;
        donttimeoutonpause = true;
        OSCfadealpha = 75;
        showtitle = true;
        showinfo = true;
        windowcontrols = false;
        volumecontrol = true;
        compactmode = false;
        bottomhover = true;
        showontop = false;
        raisesubswithosc = false;
      };
    };
    config = {
      # Quality
      profile = "gpu-hq";
      hwdec = "auto";
      vo = "gpu-next";
      scale = "ewa_lanczos";
      scale-blur = "0.981251";
      video-sync = "display-resample";
      interpolation = true;
      tscale = "oversample";
      ytdl-format = "bestvideo+bestaudio";

      # General
      save-position-on-quit = true;
      osc = "no"; # we use modernx osc

      # Subs
      sub-font = config.modules.desktop.style.font.family;
      sub-font-size = 20;
      sub-border-size = 1.5;
      sub-pos = 95;
      sub-auto = "fuzzy";

      # Screenshots
      screenshot-format = "webp";
      screenshot-webp-lossless = true;
      screenshot-high-bit-depth = true;
      screenshot-sw = false;
      screenshot-directory = "${config.xdg.userDirs.pictures}/screenshots/mpv";
      screenshot-template = "%f-%wH.%wM.%wS.%wT-#%#00n";
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

  programs.zsh.initExtra = /* bash */ ''
    screenshare () {
      if [[ -z "$1" ]]; then
          echo "Usage: screenshare <ip:port>"
          return 1
      fi
      eval "mpv 'srt://$1?mode=caller' --no-cache --profile=low-latency --untimed"
    };
    yt-dlp-audio () {
      eval "yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 -o '%(title)s.%(ext)s' '$1'"
    }
  '';

  impermanence.directories = [
    # contains state for save-position-on-quit
    ".local/state/mpv"
  ];
}
