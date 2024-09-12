{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.obs;
in
lib.mkIf cfg.enable {
  programs.obs-studio = {
    enable = true;

    package = pkgs.obs-studio.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          name = "webrtc-pacing-handler";
          # https://github.com/obsproject/obs-studio/pull/10966
          url = "https://github.com/obsproject/obs-studio/commit/2aae0f4d6849a7c23f44760f548e13f3a307426b.patch";
          hash = "sha256-VKNA0N4JHat/tLSRk3CLY+NcHsIoIvRHYfHo572KSGk=";
        })
      ];
    });

    plugins = [
      (pkgs.obs-studio-plugins.obs-pipewire-audio-capture.overrideAttrs {
        version = "2024-09-04";
        src = pkgs.fetchFromGitHub {
          owner = "dimtpap";
          repo = "obs-pipewire-audio-capture";
          rev = "7bb128951a607aa92ce4e4535df628feb19e9d88";
          sha256 = "sha256-Lp5YO/Rkwa8IRN3Nc9X8oyTu8FtiH83rnGPzWZhypVA=";
        };
        cmakeFlags = [ ];
      })
    ];
  };

  persistence.directories = [ ".config/obs-studio" ];
}
