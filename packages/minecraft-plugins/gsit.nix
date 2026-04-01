{
  lib,
  fetchurl,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gsit";
  version = "3.2.0";

  src = fetchurl {
    url = "https://github.com/gecolay/GSit/releases/download/${finalAttrs.version}/GSit-${finalAttrs.version}.jar";
    hash = "sha256-igwmppjrmTe1tk05T2nMRfAd/e/QpLX0b9YykgXv9i4=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m444 -D $src -t $out
  '';

  meta = with lib; {
    homepage = "https://hangar.papermc.io/Gecolay/GSit";
    description = "Modern Sit (Seat and Chair), Lay and Crawl - Plugin";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ JManch ];
  };
})
