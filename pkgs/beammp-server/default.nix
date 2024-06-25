{ lib
, stdenv
, fetchFromGitHub
, cmake
, lua5_3
, fmt
, openssl
, doctest
, zlib
, boost
, httplib
, libzip
, rapidjson-unstable
, sol2
, toml11
, nlohmann_json
}:
stdenv.mkDerivation rec {
  pname = "beammp-server";
  version = "3.4.1";

  src = fetchFromGitHub {
    owner = "BeamMP";
    repo = "BeamMP-Server";
    rev = "v${version}";
    hash = "sha256-dAo/HxFjXHi8F0dd9CGmyOWtWCwnKf4aKJl8A7ZzLAQ=";
    fetchSubmodules = true;
  };

  patches = [
    ./cmake.patch
  ];

  nativeBuildInputs = [
    cmake
    fmt
    openssl
    doctest
    boost
    httplib
    libzip
    rapidjson-unstable
    sol2
    toml11
    nlohmann_json
    zlib
    lua5_3
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    install BeamMP-Server -D -t "$out/bin"
  '';

  meta = with lib; {
    homepage = "https://github.com/BeamMP/BeamMP-Server";
    description = "Server for the multiplayer mod BeamMP for BeamNG.drive";
    license = [ licenses.agpl3Only ];
    maintainers = with maintainers; [ JManch ];
    mainProgram = "BeamMP-Server";
  };
}
