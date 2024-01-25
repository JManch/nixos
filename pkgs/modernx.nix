{ lib, fetchFromGitHub, makeFontsConf, stdenvNoCC }:

stdenvNoCC.mkDerivation (finalAttrs: rec {
  pname = "mpv-modernx";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "cyl0";
    repo = "ModernX";
    rev = version;
    hash = "sha256-Gpofl529VbmdN7eOThDAsNfNXNkUDDF82Rd+csXGOQg=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -m644 modernx.lua -Dt $out/share/mpv/scripts
    install -m644 Material-Design-Iconic-Font.ttf -Dt $out/share/fonts
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

  meta = {
    description = "A modern OSC UI replacement for MPV that retains the functionality of the default OSC";
    homepage = "https://github.com/cyl0/ModernX";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ JManch ];
  };
})
