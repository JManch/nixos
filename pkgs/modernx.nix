{
  lib,
  fetchFromGitHub,
  makeFontsConf,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: rec {
  pname = "mpv-modernx";
  version = "0.3.5.5";

  src = fetchFromGitHub {
    owner = "zydezu";
    repo = "ModernX";
    rev = version;
    hash = "sha256-sPpVwI8w5JsP/jML0viOSqhyYBVKfxWuKbxHkX3GVug=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -m644 modernx.lua -Dt $out/share/mpv/scripts
    install -m644 Material-Design-Iconic-Font.ttf -Dt $out/share/fonts
    install -m644 Material-Design-Iconic-Round.ttf -Dt $out/share/fonts
    runHook postInstall
  '';

  passthru.scriptName = "modernx.lua";
  passthru.extraWrapperArgs = [
    "--set"
    "FONTCONFIG_FILE"
    (toString (makeFontsConf {
      fontDirectories = [ "${finalAttrs.finalPackage}/share/fonts" ];
    }))
  ];

  meta = with lib; {
    description = "A fork of modernX (a replacement for MPV that retains the functionality of the default OSC), adding additional features";
    homepage = "https://github.com/zydezu/ModernX";
    license = licenses.free;
    maintainers = with maintainers; [ JManch ];
  };
})
