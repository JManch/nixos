{
  lib,
  fetchFromGitHub,
  makeFontsConf,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mpv-modernx";
  version = "0.3.9";

  src = fetchFromGitHub {
    owner = "zydezu";
    repo = "ModernX";
    tag = finalAttrs.version;
    hash = "sha256-wjBFI69lcsVY3HDXyz1VV5IkQvkJQQfMbGwUYmwlJ9w=";
  };

  dontBuild = true;

  installPhase = ''
    install -m644 modernx.lua -Dt $out/share/mpv/scripts
    install -m644 fluent-system-icons.ttf -Dt $out/share/fonts
  '';

  passthru = {
    scriptName = "modernx.lua";
    extraWrapperArgs = [
      "--set"
      "FONTCONFIG_FILE"
      (toString (makeFontsConf {
        fontDirectories = [ "${finalAttrs.finalPackage}/share/fonts" ];
      }))
    ];
  };

  meta = with lib; {
    description = "A fork of modernX (a replacement for MPV that retains the functionality of the default OSC), adding additional features";
    homepage = "https://github.com/zydezu/ModernX";
    license = licenses.free;
    maintainers = with maintainers; [ JManch ];
  };
})
