{
  lib,
  fetchurl,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "squaremap";
  version = "1.3.12";

  src = fetchurl {
    url = "https://github.com/jpenilla/squaremap/releases/download/v${finalAttrs.version}/squaremap-paper-mc1.21.11-${finalAttrs.version}.jar";
    hash = "sha256-M3WZS7F0v8V/y05lDSx9a+RcczjHQRh9R+EhZnrTLR4=";
  };

  squaremarker = fetchurl {
    url = "https://github.com/SentixDev/squaremarker/releases/download/1.21.11-v1.0.8/squaremarker-paper-1.0.8.jar";
    hash = "sha256-bITume9ORmp5M74MzO/7GVIAQXcHcubexm1nRkcnVyg=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m444 -D $src -t $out
    install -m444 $squaremarker -t $out
  '';

  meta = with lib; {
    homepage = "https://github.com/jpenilla/squaremap";
    description = "Minimalistic and lightweight world map viewer for Minecraft servers";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
})
