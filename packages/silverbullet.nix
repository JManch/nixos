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

    npmDepsHash = "sha256-gNkmPZO2CARVPFKavi/iDKsfIbMW/pSjDWgEYRDukK4=";

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
    # Using $clientBundle here causes:
    # "github.com/silverbulletmd/silverbullet/client_bundle: open /build/source/client_bundle: too many levels of symbolic links"
    # when `npmDepsHash` has not been set. I suspect it's because the postPatch
    # phase runs regardless of whether clientBundle is realised...
    ln -s ${finalAttrs.clientBundle} client_bundle
  '';

  preBuild = ''
    echo 'export const publicVersion = "${finalAttrs.version}";' > ./public_version.ts
  '';

  vendorHash = "sha256-8zZlhVptJq8y3k2DBghJ0lPNcIcaZYkrxN67b6dNBPs=";
  subPackages = [ "." ];
  ldflags = [ "-X main.buildTime=1970-01-01T00:00:00Z" ];
  meta.mainProgram = "silverbullet";
})
