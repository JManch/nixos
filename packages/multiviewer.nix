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
    version = "2.7.3";

    src = fetchurl {
      url = "https://releases.multiviewer.app/download/415542776/multiviewer_${final.version}_amd64.deb";
      hash = "sha256-O5yo51VHQW+t8uz6SZIzkyhznCi6Tv1xv7WU3DD7y+w=";
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
