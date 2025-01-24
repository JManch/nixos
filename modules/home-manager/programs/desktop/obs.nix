{ pkgs }:
{
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
          rev = "c8c57b39fddf01c365f3d1234edc983ee0da1b5b";
          hash = "sha256-qdwJS4WJxoIg2lIq3aHgBBrQr0Y56X4eZJzOjkwXegE=";
        };
        cmakeFlags = [ ];
      })
    ];
  };

  nsConfig.persistence.directories = [ ".config/obs-studio" ];
}
