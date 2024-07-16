{
  lib,
  fetchurl,
  makeWrapper,
  appimageTools,
  libappindicator-gtk3,
}:
let
  pname = "filen-desktop";
  version = "2.0.24";

  src = fetchurl {
    # They use an annoying system for latest version url
    # Means package will need a hash update whenever upstream updates
    # https://github.com/FilenCloudDienste/filen-desktop/issues/208
    url = "https://cdn.filen.io/desktop/release/filen_x86_64.AppImage";
    hash = "sha256-5vkndT9V/81fUdzS+KTfAjPAGO0IJRx8QhNxBNG8nnU=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  # Needed for the tray to function
  libPath = lib.makeLibraryPath [ libappindicator-gtk3 ];
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = ''
    source "${makeWrapper}/nix-support/setup-hook"
    wrapProgram $out/bin/filen-desktop \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}" \
      --prefix LD_LIBRARY_PATH : ${libPath}

    install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace 'Exec=AppRun' 'Exec=filen-desktop'
    cp -r ${appimageContents}/usr/share/icons $out/share
  '';

  meta = with lib; {
    description = "Desktop client for Filen.io";
    homepage = "https://filen.io/";
    license = licenses.agpl3Plus;
    changelog = "https://github.com/FilenCloudDienste/filen-desktop/releases/tag/v${version}";
    platforms = [ "x86_64-linux" ];
  };
}
