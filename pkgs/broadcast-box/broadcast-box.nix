{ lib
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
in
buildGoModule {
  inherit pname version src;
  vendorHash = "sha256-WDWlxeREp9iWK/wvH5guuoyThOQmCqeeM25ySEcpbkE=";

  patches = [ ./ignore-env-file.patch ];
  postPatch = ''
    substituteInPlace main.go \
      --replace-fail './web/build' '${placeholder "out"}/share'
  '';

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r ${frontend}/build/* $out/share

    mkdir -p $out/bin
    cp "$GOPATH/bin/broadcast-box" $out/bin/broadcast-box-unwrapped

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/bin/broadcast-box-unwrapped $out/bin/broadcast-box \
      --set HTTP_ADDRESS :8080 \
      --set REACT_APP_API_PATH /api
  '';

  meta = with lib; {
    description = "WebRTC broadcast server";
    homepage = "https://github.com/Glimesh/broadcast-box";
    maintainers = with maintainers; [ JManch ];
    platforms = [ "x86_64-linux" ];
    license = licenses.mit;
  };
}
