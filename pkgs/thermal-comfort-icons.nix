{ lib
, stdenvNoCC
, fetchFromGitHub
, ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "thermal-comfort-icons";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "rautesamtr";
    repo = "thermal_comfort_icons";
    rev = "refs/tags/${version}";
    sha256 = "sha256-owyG70muKxVsIOGxj4CvjLtOLRuzfNsSuUxh15V94l8=";
  };

  dontBuild = true;

  installPhase = ''
    install -D -m 755 dist/thermal_comfort_icons.js "$out"
  '';

  meta = with lib; {
    homepage = "https://github.com/rautesamtr/thermal_comfort_icons";
    description = "Thermal Comfort custom icons for Home Assistant";
    license = with licenses; [ mit asl20 ];
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
