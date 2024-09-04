{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.obs;
in
lib.mkIf cfg.enable {
  programs.obs-studio = {
    enable = true;

    package = pkgs.obs-studio.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        (pkgs.fetchpatch {
          name = "webrtc-pacing-handler";
          url = "https://patch-diff.githubusercontent.com/raw/obsproject/obs-studio/pull/10966.patch";
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
          rev = "38176824e5f95f5e2542130f6d7c027ea64536c4";
          sha256 = "sha256-z1eHz5uxfwfauO0zB/mMxzRmte5UYKGwsi3CkQu5Vhc=";
        };
        cmakeFlags = [ ];
      })
    ];
  };

  persistence.directories = [ ".config/obs-studio" ];
}
