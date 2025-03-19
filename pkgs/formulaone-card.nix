{
  lib,
  stdenvNoCC,
  sources,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "formulaone-card";
  inherit (sources.formulaone-card) version;
  src = sources.formulaone-card;

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
