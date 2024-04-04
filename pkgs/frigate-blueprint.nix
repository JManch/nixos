{ lib
, stdenvNoCC
, fetchFromGitHub
, ...
}:
stdenvNoCC.mkDerivation {
  pname = "frigate-blueprint";
  version = "04-04-2024";

  src = fetchFromGitHub {
    owner = "SgtBatten";
    repo = "HA_blueprints";
    rev = "d815163056def410023c72379897fefbdabf9cb3";
    hash = "sha256-/cFptFy22RgwkGtGL88zlSCQvZ8fpHu3OFFtZCkmfWo=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/SgtBatten"
    cp "Frigate Camera Notifications/Beta" "$out/SgtBatten/Beta.yaml"

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://github.com/SgtBatten/HA_blueprints";
    description = "A Frigate notification blueprint for Home Assistant";
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
