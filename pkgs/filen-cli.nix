{
  lib,
  buildNpmPackage,
  sources,
  pkg-config,
  libsecret,
  ...
}:
buildNpmPackage {
  pname = "filen-cli";
  inherit (sources.filen-cli) version;
  src = sources.filen-cli;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libsecret ];

  npmDepsHash = "sha256-0DpiUjUFc0ThzP6/qrSEebKDq2fnr/CpcmtPFaIVHhU=";

  meta = {
    mainProgram = "filen";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
