{
  lib,
  buildNpmPackage,
  sources,
  ...
}:
buildNpmPackage {
  pname = "filen-cli";
  inherit (sources.filen-cli) version;
  src = sources.filen-cli;

  # Why inject key at compile time???
  configurePhase = ''
    npm run generateKey
  '';

  npmDepsHash = "sha256-RXA/kVvLrmrsxj6T6H2soTMYmC6VRWNjuQfefgVB/qY=";

  meta = {
    mainProgram = "filen";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    hydraPlatforms = [ ]; # cause of the key
  };
}
