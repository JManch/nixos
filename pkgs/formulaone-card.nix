{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "formulaone-card";
  version = "1.9.7";

  src = fetchFromGitHub {
    owner = "marcokreeft87";
    repo = "formulaone-card";
    rev = version;
    hash = "sha256-OkfJPZsEgS2f0KiHIuMvto/94Uk9s4H+B7kUFoA2kZQ=";
  };

  dontBuild = true;

  installPhase = ''
    install -D formulaone-card.js -t $out/formulaone-card
  '';

  meta = with lib; {
    homepage = "https://github.com/marcokreeft87/formulaone-card";
    description = "Present the data of Formula One in a pretty way";
    license = licenses.mit;
    maintainers = with maintainers; [ JManch ];
    platforms = platforms.linux;
  };
}
