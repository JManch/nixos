{
  lib,
  fetchzip,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "advanced-camera-card";
  version = "7.3.6";

  src = fetchzip {
    url = "https://github.com/dermotduffy/${finalAttrs.pname}/releases/download/v${finalAttrs.version}/${finalAttrs.pname}.zip";
    hash = "sha256-+sDIs1r3668FrpnJ3qcQlrfDvtapODj5LVOb6yStSA8=";
  };

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/advanced-camera-card
    mv * $out/advanced-camera-card
  '';

  meta = {
    homepage = "https://github.com/dermotduffy/frigate-hass-card";
    description = "A Lovelace card for Frigate in Home Assistant";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
