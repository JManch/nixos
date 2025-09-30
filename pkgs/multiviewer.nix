{
  lib,
  multiviewer-for-f1,
  fetchurl,
  libudev0-shim,
  libglvnd,
  icoutils,
}:
multiviewer-for-f1.overrideAttrs (
  final: prev: {
    pname = "multiviewer";
    version = "2.2.1";

    src = fetchurl {
      url = "https://releases.multiviewer.app/download/295039426/multiviewer_${final.version}_amd64.deb";
      hash = "sha256-y40LJVjnkvIxElDooF5xNmpkeVCRRS30o/nvqZnmH+I=";
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

    # Fix the icon because it uses an unreadable windows format
    # postInstall = ''
    #   ${lib.getExe' icoutils "icotool"} -x -w 256 -o $out/share/pixmaps/multiviewer.png $out/share/pixmaps/multiviewer.png
    # '';

    meta = prev.meta // {
      mainProgram = "multiviewer";
    };
  }
)
