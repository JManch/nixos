{
  lib,
  multiviewer-for-f1,
  fetchurl,
  libudev0-shim,
  libglvnd,
}:
multiviewer-for-f1.overrideAttrs (
  final: prev: {
    pname = "multiviewer";
    version = "2.3.0";

    src = fetchurl {
      url = "https://releases.multiviewer.app/download/305607196/multiviewer_${final.version}_amd64.deb";
      hash = "sha256-Uc4db2o4XBV9eRNugxS6pA9Z5YhjY5QnEkwOICXmUwc=";
    };

    # Add libglvnd to library path for hardware acceleration
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/share
      mv -t $out/share usr/share/* usr/lib/multiviewer

      makeWrapper "$out/share/multiviewer/multiviewer" $out/bin/multiviewer \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            libudev0-shim
            libglvnd
          ]
        }:\"$out/share/multiviewer\""

      runHook postInstall
    '';

    meta = prev.meta // {
      mainProgram = "multiviewer";
    };
  }
)
