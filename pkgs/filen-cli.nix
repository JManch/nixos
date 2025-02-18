{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "filen-cli";
  version = "0.0.29";

  src = fetchFromGitHub {
    owner = "FilenCloudDienste";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-ftbRv75x6o1HgElY4oLBBe5SRuLtxdrjpjZznSCyroI=";
  };

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
