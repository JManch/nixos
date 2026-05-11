{
  lib,
  gitMinimal,
  buildGoModule,
  buildNpmPackage,
  sources,
}:
buildGoModule (finalAttrs: {
  pname = "silverbullet";
  inherit (sources.silverbullet) version;
  src = sources.silverbullet;

  clientBundle = buildNpmPackage {
    pname = "silverbullet-client-bundle";
    inherit (finalAttrs) src version;

    nativeBuildInputs = [ gitMinimal ];

    npmDepsHash = "sha256-cn7s7JK6JV9NF0w+gTU56Y3bnR0xKMzvNRlh5GIpuA8=";

    buildPhase = ''
      runHook preBuild

      npm run build:plugs
      # The version gets embeded during the build and must match the server
      # version otherwise the client spams "a new version of SilverBullet
      # client is available" messages.
      echo 'export const publicVersion = "${finalAttrs.version}";' > ./public_version.ts
      npm run build:client

      runHook postBuild
    '';

    dontCheckForBrokenSymlinks =
      assert lib.assertMsg (
        finalAttrs.version == "2.7.0"
      ) "Silverbullet broken symlink check can be re-enabled";
      true;

    installPhase = ''
      cp -r client_bundle $out
    '';
  };

  postPatch = ''
    rm -r client_bundle
    ln -s $clientBundle client_bundle
  '';

  preBuild = ''
    echo 'export const publicVersion = "${finalAttrs.version}";' > ./public_version.ts
  '';

  vendorHash = "sha256-SvMPyJbSVrj+lwXrNh2WEYNI41oqlzchFxCtXvIl4/4=";
  subPackages = [ "." ];
  ldflags = [ "-X main.buildTime=1970-01-01T00:00:00Z" ];
  meta.mainProgram = "silverbullet";
})
