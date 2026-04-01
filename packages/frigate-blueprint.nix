{
  lib,
  stdenvNoCC,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "frigate-blueprint";
  version = "0-unstable-${sources.HA_blueprints.revision}";
  src = sources.HA_blueprints;
  # patches = [ ../patches/frigate-blueprint.patch ];

  dontBuild = true;

  installPhase = ''
    install -D Frigate_Camera_Notifications/Beta.yaml -T $out/frigate_notifications.yaml
  '';

  meta = with lib; {
    homepage = "https://github.com/SgtBatten/HA_blueprints";
    description = "A Frigate notification blueprint for Home Assistant";
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
