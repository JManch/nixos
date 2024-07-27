{
  lib,
  fetchzip,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "frigate-hass-card";
  version = "5.2.0";

  src = fetchzip {
    url = "https://github.com/dermotduffy/frigate-hass-card/releases/download/v${version}/frigate-hass-card.zip";
    sha256 = "sha256-g8Rg6Y3KN1DLexqEPUt61PotpeBSCo3rD4iSz97ml+U=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/frigate-hass-card
    mv * $out/frigate-hass-card
  '';

  meta = with lib; {
    homepage = "https://github.com/dermotduffy/frigate-hass-card";
    description = "A Lovelace card for Frigate in Home Assistant";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
