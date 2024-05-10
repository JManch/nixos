{ lib
, fetchurl
, stdenvNoCC
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "tab-tps";
  version = "1.3.22";

  src = fetchurl {
    url = "https://github.com/jpenilla/TabTPS/releases/download/v${version}/tabtps-spigot-${version}.jar";
    sha256 = "sha256-3Dwj10HNgPG+Bc2V2jRwHiQBDiQMOJcPdmz+JMPtuaM=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/jpenilla/TabTPS";
    description = "Minecraft server mod/plugin to monitor TPS";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
}
