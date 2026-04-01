{
  lib,
  stdenv,
  cmake,
  zlib,
  httplib,
  nlohmann_json,
  openssl,
  curl,
  sources,
  installShellFiles,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-launcher";
  inherit (sources.BeamMP-Launcher) version;
  src = sources.BeamMP-Launcher;
  strictDeps = true;

  nativeBuildInputs = [
    cmake
    installShellFiles
  ];

  buildInputs = [
    zlib
    httplib
    nlohmann_json
    openssl
    curl
  ];

  enableParallelBuilding = true;

  installPhase = ''
    installBin BeamMP-Launcher
  '';

  meta = {
    homepage = "https://github.com/BeamMP/BeamMP-Launcher";
    description = "Official BeamMP Launcher";
    license = [ lib.licenses.unfree ];
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "BeamMP-Launcher";
  };
})
