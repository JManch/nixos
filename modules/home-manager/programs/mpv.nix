{
  ns,
  lib,
  pkgs,
  config,
  selfPkgs,
  ...
}:
let
  inherit (lib) mkIf hiPrio optional;
  cfg = config.${ns}.programs.mpv;
in
mkIf cfg.enable {
  home.packages = [
    pkgs.yt-dlp
    (hiPrio (
      pkgs.runCommand "mpv-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${config.programs.mpv.finalPackage}/share/applications/mpv.desktop $out/share/applications/mpv.desktop \
          --replace-fail "Name=mpv Media Player" "Name=MPV Media Player"
        substitute ${config.programs.mpv.finalPackage}/share/applications/umpv.desktop $out/share/applications/umpv.desktop \
          --replace-fail "Name=umpv Media Player" "Name=UMPV Media Player"
      ''
    ))
  ] ++ optional cfg.jellyfinShim.enable pkgs.jellyfin-mpv-shim;

  programs.mpv = {
    enable = true;

    scripts = [
      pkgs.mpvScripts.thumbfast
      pkgs.mpvScripts.sponsorblock-minimal
      selfPkgs.modernx
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
        bottomhover = false;
        showontop = false;
        raisesubswithosc = false;
      };
    };

    config = {
      # Quality
      profile = "high-quality";
      hwdec = "auto-safe";
      vo = "gpu-next";
      video-sync = "display-resample";
      interpolation = true;
      tscale = "oversample";
      ytdl-format = "bestvideo+bestaudio";

      # General
      save-position-on-quit = false;
      osc = "no"; # we use modernx osc

      # Subs
      sub-font = config.${ns}.desktop.style.font.family;
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
      E = "add panscan -0.1"; # because jellyfin shim overrides w
      l = "no-osd seek 100 absolute-percent"; # jump to live
    };
  };

  xdg.configFile = mkIf cfg.jellyfinShim.enable {
    "jellyfin-mpv-shim/mpv.conf".source = config.xdg.configFile."mpv/mpv.conf".source;
    "jellyfin-mpv-shim/input.conf".source = config.xdg.configFile."mpv/input.conf".source;
  };

  programs.zsh.initExtra = # bash
    ''
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

  desktop.hyprland.settings.windowrulev2 = [
    "workspace emptym, class:^(mpv)$"
  ];

  persistence.directories = optional cfg.jellyfinShim.enable ".config/jellyfin-mpv-shim";
}
