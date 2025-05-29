{ lib, pkgs }:
{
  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-pipewire-audio-capture ];

    package =
      lib.${lib.ns}.addPatches
        # Have to use obs 30.2.3 as the OBS WHEP source patch has not been rebased onto latest version
        (import (fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/028048884dc9517e548703beb24a11408cc51402.tar.gz";
          sha256 = "sha256:0gamch7a5586q568s8i5iszxljm1lw791k507crzcwqrcm41rs8y";
        }) { inherit (pkgs) system; }).obs-studio
        [
          # https://github.com/obsproject/obs-studio/pull/10353
          "obs-whep-source.patch"
          (pkgs.fetchpatch {
            name = "webrtc-pacing-handler";
            # https://github.com/obsproject/obs-studio/pull/10966
            url = "https://github.com/obsproject/obs-studio/commit/2aae0f4d6849a7c23f44760f548e13f3a307426b.patch";
            hash = "sha256-VKNA0N4JHat/tLSRk3CLY+NcHsIoIvRHYfHo572KSGk=";
          })
        ];
  };

  ns.persistence.directories = [ ".config/obs-studio" ];
}
