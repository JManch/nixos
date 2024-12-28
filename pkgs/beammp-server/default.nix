{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  lua5_3,
  fmt,
  openssl,
  doctest,
  zlib,
  boost,
  httplib,
  libzip,
  rapidjson,
  sol2,
  toml11,
  nlohmann_json,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-server";
  version = "3.7.2";

  src = fetchFromGitHub {
    owner = "BeamMP";
    repo = "BeamMP-Server";
    rev = "v${finalAttrs.version}";
    hash = "sha256-xp0XTzG9HGiPXNTnG+OM2cgLYG049hYdEj4YYlVIse4=";
    fetchSubmodules = true;
  };

  patches = [ ./cmake.patch ];

  nativeBuildInputs = [
    cmake
    fmt
    openssl
    doctest
    boost
    httplib
    libzip
    rapidjson
    sol2
    toml11
    nlohmann_json
    zlib
    lua5_3
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

  enableParallelBuilding = true;

  installPhase = ''
    install BeamMP-Server -D -t "$out/bin"
  '';

  meta = {
    homepage = "https://github.com/BeamMP/BeamMP-Server";
    description = "Server for the multiplayer mod BeamMP for BeamNG.drive";
    license = [ lib.licenses.agpl3Only ];
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "BeamMP-Server";
  };
})
