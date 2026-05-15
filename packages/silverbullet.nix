{
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

    npmDepsHash = "sha256-g5IAIIXUGzOIRrnAcUH1MWYBD8cZqpZPx3hpUA4O/iE=";

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

  vendorHash = "sha256-8zZlhVptJq8y3k2DBghJ0lPNcIcaZYkrxN67b6dNBPs=";
  subPackages = [ "." ];
  ldflags = [ "-X main.buildTime=1970-01-01T00:00:00Z" ];
  meta.mainProgram = "silverbullet";
})
