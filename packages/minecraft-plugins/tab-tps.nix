{
  lib,
  fetchurl,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "tab-tps";
  version = "1.3.30";

  src = fetchurl {
    url = "https://cdn.modrinth.com/data/cUhi3iB2/versions/Jpi3Z1lp/tabtps-paper-1.3.30.jar";
    hash = "sha256-zeH1CH0TC0DziZnMazLEo5pBSsEJFhMSAb+wCUliKBA=";
  };

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    install -m444 -D $src -t $out
  '';

  meta = with lib; {
    homepage = "https://github.com/jpenilla/TabTPS";
    description = "Minecraft server mod/plugin to monitor TPS";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
  };
}
