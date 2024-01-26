{ lib, fetchFromGitHub, makeFontsConf, stdenvNoCC }:

stdenvNoCC.mkDerivation (finalAttrs: rec {
  pname = "mpv-modernx";
  version = "0.2.6";

  src = fetchFromGitHub {
    owner = "zydezu";
    repo = "ModernX";
    rev = version;
    hash = "sha256-6iVQuSDMC6Pg5TuxVgsVnoq9mmFAU31t0HFeOOoU0SU=";
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

  meta = {
    description = "A fork of modernX (a replacement for MPV that retains the functionality of the default OSC), adding additional features";
    homepage = "https://github.com/zydezu/ModernX";
    license = lib.licenses.free;
    maintainers = with lib.maintainers; [ JManch ];
  };
})
