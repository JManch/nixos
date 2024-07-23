{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "frigate-blueprint";
  version = "0.12.0.4";

  src = fetchFromGitHub {
    owner = "SgtBatten";
    repo = "HA_blueprints";
    rev = "v${version}";
    hash = "sha256-HBetLcRli6I+E/+s35SDFilUi90yhR+ccbPVG/a0muA=";
  };

  patches = [ ../patches/frigateBlueprint.patch ];

  dontBuild = true;

  installPhase = ''
    mkdir -p "$out"
    cp "Frigate Camera Notifications/Beta" "$out/frigate_notifications.yaml"
  '';

  meta = with lib; {
    homepage = "https://github.com/SgtBatten/HA_blueprints";
    description = "A Frigate notification blueprint for Home Assistant";
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
