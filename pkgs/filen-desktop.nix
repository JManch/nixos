{
  fetchurl,
  makeWrapper,
  appimageTools,
}:
let
  pname = "filen-desktop";
  version = "3.0.41";

  src = fetchurl {
    # They use an annoying system for latest version url
    # Means package will need a hash update whenever upstream updates
    # https://github.com/FilenCloudDienste/filen-desktop/issues/208
    url = "https://github.com/FilenCloudDienste/filen-desktop/releases/download/v${version}/Filen_linux_x86_64.AppImage";
    hash = "sha256-Nao5By8Z8lMbRcp2Mgw+xaiiFzUxCm6S3SAE5FfDZpk=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 rec {
  inherit pname version src;

  extraInstallCommands = # bash
    ''
      source "${makeWrapper}/nix-support/setup-hook"
      wrapProgram $out/bin/filen-desktop \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform=wayland --enable-features=WaylandWindowDecorations}}"

      install -m 644 -D ${appimageContents}/@filendesktop.desktop $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=filen-desktop'
      cp --no-preserve=mode -r ${appimageContents}/usr/share/icons $out/share
      find $out/share/icons/hicolor -type f -name "@filendesktop.png" -execdir mv {} filen-desktop.png \;
    '';
}
