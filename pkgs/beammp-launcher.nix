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
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-launcher";
  inherit (sources.BeamMP-Launcher) version;
  src = sources.BeamMP-Launcher;

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    zlib
    httplib
    nlohmann_json
    openssl
    curl
  ];

  enableParallelBuilding = true;

  installPhase = ''
    install BeamMP-Launcher -D -t $out/bin
  '';

  meta = {
    homepage = "https://github.com/BeamMP/BeamMP-Launcher";
    description = "Official BeamMP Launcher";
    license = [ lib.licenses.unfree ];
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "BeamMP-Launcher";
  };
})
