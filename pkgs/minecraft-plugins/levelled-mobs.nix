{ lib
, fetchurl
, fetchFromGitHub
, stdenvNoCC
, ...
}:
let
  srcRepo = fetchFromGitHub {
    owner = "ArcanePlugins";
    repo = "LevelledMobs";
    rev = "a85cf9da01c23c0cb655bb34e7c5a81c75a19a23";
    sha256 = "sha256-TQHNKAlgSBoYb5NHiDpww12gD8mYTC7QceFK7CdT8+A=";
  };
in
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
    install -m444 -D ${srcRepo}/src/main/resources/* -t "$out/config"
  '';

  meta = with lib; {
    homepage = "https://github.com/ArcanePlugins/LevelledMobs";
    description = "Level-up mobs on your Spigot/Paper server";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
}
