{
  lib,
  stdenvNoCC,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "frigate-blueprint";
  inherit (sources.HA_blueprints) version;
  src = sources.HA_blueprints;

  patches = [ ../patches/frigate-blueprint.patch ];

  dontBuild = true;

  installPhase = ''
    mkdir -p "$out"
    cp "Frigate Camera Notifications/Stable" "$out/frigate_notifications.yaml"
  '';

  meta = with lib; {
    homepage = "https://github.com/SgtBatten/HA_blueprints";
    description = "A Frigate notification blueprint for Home Assistant";
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
