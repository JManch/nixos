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

  npmDepsHash = "sha256-a+sq0vFsk4c7bl0Nn2KfBFxyq3ZF2HPvt8d1vxegnHg=";

  meta = {
    mainProgram = "filen";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    hydraPlatforms = [ ]; # cause of the key
  };
}
