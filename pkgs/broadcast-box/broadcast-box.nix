{ lib
, stdenvNoCC
, makeWrapper
, buildGoModule
, buildNpmPackage
, fetchFromGitHub
}:
let
  pname = "broadcast-box";
  version = "unstable-2024-2-5";

  src = fetchFromGitHub {
    repo = "broadcast-box";
    owner = "Glimesh";
    rev = "2ae2fd17bf05bd72ea44cfdc191acc4391c89c2a";
    sha256 = "sha256-Pb9c/ivJju9B7QTEprQJE1d4NMTwC6hHDy4rCienUII=";
  };

  frontend = buildNpmPackage {
    pname = "${pname}-web";
    inherit version;
    src = "${src}/web";
    npmDepsHash = "sha256-3wO9d2WlPONimXXfU0W17Vg9u4IBAGZC9UV00kVst7s=";
    preBuild = ''
      # The REACT_APP_API_PATH environment variable is needed
      cp "${src}/.env.production" ../
    '';
    installPhase = ''
      mkdir -p $out/build
      cp -r build $out
    '';
  };

  backend = buildGoModule {
    pname = pname;
    inherit version src;
    patches = [ ./ignore-env-file.patch ];
    vendorHash = "sha256-WDWlxeREp9iWK/wvH5guuoyThOQmCqeeM25ySEcpbkE=";
  };
in
stdenvNoCC.mkDerivation {
  pname = pname;
  inherit version src;
  vendorHash = "sha256-8iIQ4gv6P8CvNdAaeOOiQTsyduykMzmjLbZJzPaABBg=";
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/web
    cp -r ${frontend}/build $out/share/web

    mkdir -p $out/bin
    cp ${backend}/bin/broadcast-box $out/bin/broadcast-box-unwrapped

    makeWrapper $out/bin/broadcast-box-unwrapped $out/bin/broadcast-box \
      --set HTTP_ADDRESS :8080 \
      --set REACT_APP_API_PATH /api

    runHook postInstall
  '';

  meta = with lib; {
    description = "WebRTC broadcast server";
    homepage = "https://github.com/Glimesh/broadcast-box";
    maintainers = with maintainers; [ JManch ];
    platforms = [ "x86_64-linux" ];
    license = licenses.mit;
  };
}
