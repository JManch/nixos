{
  lib,
  stdenv,
  cmake,
  lua5_3,
  fmt,
  openssl,
  doctest,
  zlib,
  boost186,
  httplib,
  libzip,
  rapidjson,
  sol2,
  toml11,
  nlohmann_json,
  curl,
  sources,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-server";
  inherit (sources.BeamMP-Server) version;
  src = sources.BeamMP-Server;

  patches = [ ./cmake.patch ];

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    curl
    fmt
    openssl
    doctest
    boost186
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
