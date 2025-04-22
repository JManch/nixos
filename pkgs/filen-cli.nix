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

  npmDepsHash = "sha256-4GdipHnaqv3LrejMXF73duNyZKgD/0ApzUjiI/QQ30g=";

  meta = {
    mainProgram = "filen";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
