{ lib
, multiviewer-for-f1
, fetchurl
, libudev0-shim
, libglvnd
, ...
}:
multiviewer-for-f1.overrideAttrs rec {
  version = "1.34.4";

  src = fetchurl {
    url = "https://releases.multiviewer.app/download/178062561/multiviewer-for-f1_${version}_amd64.deb";
    sha256 = "sha256-9p5wtTwYAmMMoRU1nIX3l5W4O1R2jS7pgumXOGEN6f4=";
  };

  # Add libglvnd to library path for hardware acceleration
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    mv -t $out/share usr/share/* usr/lib/multiviewer-for-f1

    makeWrapper "$out/share/multiviewer-for-f1/MultiViewer for F1" $out/bin/multiviewer-for-f1 \
    --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
    --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libudev0-shim libglvnd ]}:\"$out/share/Multiviewer for F1\""

    runHook postInstall
  '';
}
