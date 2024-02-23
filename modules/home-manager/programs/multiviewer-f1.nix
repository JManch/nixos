{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.multiviewerF1;
in
lib.mkIf cfg.enable
{
  home.packages = [
    (pkgs.multiviewer-for-f1.overrideAttrs
      (_: {
        version = "1.31.0";
        src = pkgs.fetchurl {
          url = "https://releases.multiviewer.app/download/152564927/multiviewer-for-f1_1.31.0_amd64.deb";
          sha256 = "sha256-M4ILpP4voOPDG6MqgVuEF1HiJPAKQ5nFwMEz2PXiDMY=";
        };
        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin $out/share
          mv -t $out/share usr/share/* usr/lib/multiviewer-for-f1

          makeWrapper "$out/share/multiviewer-for-f1/MultiViewer for F1" $out/bin/multiviewer-for-f1 \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libudev0-shim pkgs.libglvnd ]}:\"$out/share/Multiviewer for F1\""

          runHook postInstall
        '';
      }))
  ];

  persistence.directories = [
    ".config/MultiViewer for F1"
  ];
}
