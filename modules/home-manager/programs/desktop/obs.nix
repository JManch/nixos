{ pkgs }:
{
  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-pipewire-audio-capture ];

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
  };

  ns.persistence.directories = [ ".config/obs-studio" ];
}
