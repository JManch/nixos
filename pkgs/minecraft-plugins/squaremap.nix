{ lib
, fetchurl
, stdenvNoCC
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "squaremap";
  version = "1.2.3";

  src = fetchurl {
    url = "https://github.com/jpenilla/squaremap/releases/download/v${version}/squaremap-paper-mc1.20.4-${version}.jar";
    sha256 = "sha256-DNRPdTngzNw4FmGxXxUs7wLNevRxBnhpcIv7XxttzHA=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/jpenilla/squaremap";
    description = "Minimalistic and lightweight world map viewer for Minecraft servers";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
}
