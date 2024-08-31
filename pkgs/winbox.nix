{
  lib,
  stdenvNoCC,
  fetchzip,
  autoPatchelfHook,
  xorg,
  freetype,
  fontconfig,
  libGL,
  libz,
  libxkbcommon,
  makeDesktopItem,
  copyDesktopItems,
}:
stdenvNoCC.mkDerivation {
  pname = "winbox-v4";
  version = "3.0-unstable-2024-08-29";

  src = fetchzip {
    url = "https://download.mikrotik.com/routeros/winbox/4.0beta3/WinBox_Linux.zip";
    stripRoot = false;
    hash = "sha256-IVQGImEtwpBepj4ualjAZBRM3qexdVnyhKYDGqbghOo=";
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    xorg.libxcb
    xorg.xcbutilwm
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    freetype
    fontconfig
    libGL
    libz
    libxkbcommon
  ];

  installPhase = ''
    runHook preInstall

    install WinBox -Dt $out/bin
    install assets/img/winbox.png -DT $out/share/pixmaps/winbox-v4.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "winbox-v4";
      desktopName = "Winbox v4";
      comment = "GUI administration for Mikrotik RouterOS";
      exec = "WinBox";
      icon = "winbox-v4";
      categories = [ "Utility" ];
    })
  ];

  meta = {
    description = "Graphical configuration utility for RouterOS-based devices";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    mainProgram = "WinBox";
    maintainers = with lib.maintainers; [ JManch ];
  };
}
