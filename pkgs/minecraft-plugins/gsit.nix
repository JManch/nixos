{
  lib,
  fetchurl,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "gsit";
  version = "1.9.1";

  src = fetchurl {
    url = "https://hangarcdn.papermc.io/plugins/Gecolay/GSit/versions/${version}/PAPER/GSit-${version}.jar";
    sha256 = "sha256-6JZMJ7f2dKd/uHLzbm2pVI4q/yfbSaCDSewTtyH8SG4=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m555 -D ${src} -t "$out"
  '';

  meta = with lib; {
    homepage = "https://hangar.papermc.io/Gecolay/GSit";
    description = "Modern Sit (Seat and Chair), Lay and Crawl - Plugin";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
}
