{ lib
, fetchurl
, stdenvNoCC
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "levelled-mobs";
  version = "3.15.4";

  src = fetchurl {
    url = "https://hangarcdn.papermc.io/plugins/ArcanePlugins/LevelledMobs/versions/3.15.4-b841/PAPER/LevelledMobs-3.15.4%20b841.jar";
    sha256 = "sha256-5pKFr5OGM7K2RcjjOBgwRnyE1/5GVaV6aYdp8/RFVCs=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/ArcanePlugins/LevelledMobs";
    description = "Level-up mobs on your Spigot/Paper server";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
}
