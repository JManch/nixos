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
  boost186,
  httplib,
  libzip,
  rapidjson,
  sol2,
  toml11,
  nlohmann_json,
  curl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-server";
  version = "3.8.2";

  src = fetchFromGitHub {
    owner = "BeamMP";
    repo = "BeamMP-Server";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Q790VQEc5Z9L0rLNSxdt1ipAAQeB4r6bq+gF6C3Skb4=";
    fetchSubmodules = true;
  };

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
