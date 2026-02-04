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
  fetchFromGitHub,
  installShellFiles,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "beammp-server";
  inherit (sources.BeamMP-Server) version;
  src = sources.BeamMP-Server;
  strictDeps = true;

  patches = [ ./cmake.patch ];

  nativeBuildInputs = [
    cmake
    installShellFiles
  ];

  buildInputs = [
    curl
    fmt
    openssl
    doctest
    boost186
    httplib
    libzip
    rapidjson
    (sol2.overrideAttrs {
      version = "3.3.1";
      src = fetchFromGitHub {
        owner = "ThePhD";
        repo = "sol2";
        rev = "v3.3.1";
        hash = "sha256-7QHZRudxq3hdsfEAYKKJydc4rv6lyN6UIt/2Zmaejx8=";
      };
    })
    toml11
    nlohmann_json
    zlib
    lua5_3
  ];

  enableParallelBuilding = true;

  installPhase = ''
    installBin BeamMP-Server
  '';

  meta = {
    homepage = "https://github.com/BeamMP/BeamMP-Server";
    description = "Server for the multiplayer mod BeamMP for BeamNG.drive";
    license = [ lib.licenses.agpl3Only ];
    maintainers = with lib.maintainers; [ JManch ];
    mainProgram = "BeamMP-Server";
    broken = true;
  };
})
