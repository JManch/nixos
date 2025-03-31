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

  npmDepsHash = "sha256-RXA/kVvLrmrsxj6T6H2soTMYmC6VRWNjuQfefgVB/qY=";

  meta = {
    mainProgram = "filen";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
