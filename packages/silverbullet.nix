{
  gitMinimal,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
}:
buildGoModule (finalAttrs: {
  client = buildNpmPackage {
    pname = "silverbullet-client";
    inherit (finalAttrs) version;

    src = fetchFromGitHub {
      owner = "silverbulletmd";
      repo = "silverbullet";
      tag = finalAttrs.version;
      hash = "sha256-6Jpo7Nugais7KaFnkyzKttZDHcwgcFGMlVXa2gGcmqk=";
    };

    nativeBuildInputs = [ gitMinimal ];

    npmDepsHash = "sha256-cn7s7JK6JV9NF0w+gTU56Y3bnR0xKMzvNRlh5GIpuA8=";

    buildPhase = ''
      runHook preBuild

      npm run build
      npm run build:plug-compile

      runHook postBuild
    '';

    dontCheckForBrokenSymlinks = true;

    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
  };

  # TODO: Figure out how to exclude the CLI package from building and package it separately
  pname = "silverbullet";
  version = "2.7.0";
  src = finalAttrs.client;
  vendorHash = "sha256-SvMPyJbSVrj+lwXrNh2WEYNI41oqlzchFxCtXvIl4/4=";
  doCheck = false;
  meta.mainProgram = "silverbullet";
})
