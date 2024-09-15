{
  lib,
  multiviewer-for-f1,
  fetchurl,
  libudev0-shim,
  libglvnd,
  icoutils,
  ...
}:
multiviewer-for-f1.overrideAttrs rec {
  version = "1.36.1";

  src = fetchurl {
    url = "https://releases.multiviewer.app/download/192684463/multiviewer-for-f1_${version}_amd64.deb";
    hash = "sha256-qbkig46BIr8Cs6GPZDBRalimjb+QK7PfkBJvQXIrYgw=";
  };

  # Add libglvnd to library path for hardware acceleration
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    mv -t $out/share usr/share/* usr/lib/multiviewer-for-f1

    makeWrapper "$out/share/multiviewer-for-f1/MultiViewer for F1" $out/bin/multiviewer-for-f1 \
    --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
    --prefix LD_LIBRARY_PATH : "${
      lib.makeLibraryPath [
        libudev0-shim
        libglvnd
      ]
    }:\"$out/share/Multiviewer for F1\""

    runHook postInstall
  '';

  # Fix the icon because it uses an unreadable windows format
  postInstall = ''
    ${lib.getExe' icoutils "icotool"} -x -w 256 -o $out/share/pixmaps/multiviewer-for-f1.png $out/share/pixmaps/multiviewer-for-f1.png
  '';
}
