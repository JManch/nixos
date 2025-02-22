{
  lib,
  fetchzip,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "frigate-hass-card";
  version = "6.2.2";

  src = fetchzip {
    url = "https://github.com/dermotduffy/frigate-hass-card/releases/download/v${version}/frigate-hass-card.zip";
    hash = "sha256-NUZW/oxa7jy1a9cdIiHtGlTKAjIHtMEVGL9vb2x1JXI=";
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
