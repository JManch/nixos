{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  zlib,
  httplib,
  nlohmann_json,
  openssl,
  curl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-launcher";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "BeamMP";
    repo = "BeamMP-Launcher";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ZSwmX1y8LjWzoJn5ATvvLRf9zOEi+8ERvWuZulV7knI=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    zlib
    httplib
    nlohmann_json
    openssl
    curl
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
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
