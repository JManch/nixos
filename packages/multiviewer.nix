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
    version = "2.6.0";

    src = fetchurl {
      url = "https://releases.multiviewer.app/download/367699519/multiviewer_${final.version}_amd64.deb";
      hash = "sha256-tlDrPA1drM/rNtiXb1GZPzxkCwYi3I9Gkvr3tJ9YzcI=";
    };

    # Add libglvnd to library path for hardware acceleration
    installPhase = ''
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
    '';

    meta = prev.meta // {
      mainProgram = "multiviewer";
    };
  }
)
