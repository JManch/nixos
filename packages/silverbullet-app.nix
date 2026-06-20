{
  fetchurl,
  appimageTools,
}:
let
  pname = "silverbullet-app";
  version = "2.9.0";

  src = fetchurl {
    url = "https://releases.silverbullet.plus/releases/2.9.0/SilverBullet_x86_64.AppImage";
    hash = "sha256-GtiLG6cnZIwwMGjINYEzboCTi+0weUX7zvrtmgA7y4c=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/SilverBullet.desktop \
      $out/share/applications/SilverBullet.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/silverbullet-app.png \
      $out/share/icons/hicolor/1024x1024/apps/silverbullet-app.png
  '';
}
