{
  fetchurl,
  appimageTools,
  imagemagick,
}:
let
  pname = "silverbullet-app";
  version = "2.11.0";

  src = fetchurl {
    url = "https://releases.silverbullet.plus/releases/2.11.0/SilverBullet_x86_64.AppImage";
    hash = "sha256-7YQ0GId03Qfzd6Au60jC3z3mm5NZi2bQTto7bL5PF58=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cat > $out/share/applications/silverbullet-app.desktop <<EOF
    [Desktop Entry]
    Name=SilverBullet
    Comment=Programmable note taking app
    Exec=silverbullet-app %u
    Icon=silverbullet-app
    Type=Application
    Terminal=false
    Categories=Office;TextEditor;
    StartupWMClass=silverbullet-app
    MimeType=x-scheme-handler/silverbullet;
    EOF

    icon=${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/silverbullet-app.png
    for size in 16 24 32 48 64 128 256 512; do
      dir=$out/share/icons/hicolor/''${size}x''${size}/apps
      mkdir -p $dir
      ${imagemagick}/bin/magick $icon -resize ''${size}x''${size} $dir/silverbullet-app.png
    done
    install -m 444 -D $icon $out/share/icons/hicolor/1024x1024/apps/silverbullet-app.png
  '';
}
