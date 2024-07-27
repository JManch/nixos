{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "formulaone-card";
  version = "1.9.2";

  src = fetchFromGitHub {
    owner = "marcokreeft87";
    repo = "formulaone-card";
    rev = version;
    hash = "sha256-n6z9ujgp1FSrNS0gvyX22/CTT4EXVPFCd+GboA8Jj1M=";
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
