{
  lib,
  cfg,
  pkgs,
  config,
  sources,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    hiPrio
    optional
    mkOption
    types
    mkEnableOption
    ;
  inherit (osConfig.${ns}.core) device;
in
{
  opts = {
    jellyfinShim.enable = mkEnableOption "mpv jellyfin shim";

    highQuality = mkOption {
      type = types.bool;
      default = device.type != "laptop";
      description = "Whether to use high quality or fast profile";
    };

    interpolate = mkOption {
      type = types.bool;
      default = device.type != "laptop";
      description = ''
        Whether to enable interpolation and display-resample video-sync.
        Increases GPU usage a lot especially on devices with high refresh rate
        displays.
      '';
    };
  };

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
  ]
  ++ optional cfg.jellyfinShim.enable pkgs.jellyfin-mpv-shim;

  programs.mpv = {
    enable = true;

    scripts = [
      (pkgs.stdenvNoCC.mkDerivation {
        pname = "thumbfast-vanilla-osc";
        version = "0-unstable-${sources.thumbfast-vanilla-osc.revision}";
        src = sources.thumbfast-vanilla-osc;
        installPhase = "install -m644 player/lua/osc.lua -Dt $out/share/mpv/scripts";
        passthru.scriptName = "osc.lua";
      })
      pkgs.mpvScripts.thumbfast
      pkgs.mpvScripts.sponsorblock-minimal
      pkgs.mpvScripts.mpris
    ];

    config = {
      # Quality
      profile = if cfg.highQuality then "high-quality" else "fast";
      hwdec = "auto-safe";
      vo = "gpu-next";
      interpolation = cfg.interpolate;
      video-sync = mkIf cfg.interpolate "display-resample";
      tscale = "oversample";
      ytdl-format = "bestvideo+bestaudio";

      # General
      save-position-on-quit = false;
      volume = 50;

      # Subs
      sub-font = config.${ns}.desktop.style.font.family;
      sub-scale = 0.7;
      sub-font-size = 38;
      sub-pos = 97;
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

  xdg.desktopEntries.mpv-open-clipboard = {
    name = "MPV Open Clipboard";
    genericName = "Multimedia player";
    exec = (pkgs.writeShellScript "mpv-open-clipboard" "mpv $(wl-paste)").outPath;
    type = "Application";
    icon = "mpv";
    categories = [ "AudioVideo" ];
  };

  programs.zsh.initContent = # bash
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

  ns.desktop.hyprland.settings.windowrule = [ "workspace emptym, class:^(mpv)$" ];

  ns.persistence.directories = optional cfg.jellyfinShim.enable ".config/jellyfin-mpv-shim";
}
