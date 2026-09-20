{
  rustPlatform,
  buildNpmPackage,
  gitMinimal,
  sources,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "silverbullet";
  version = "0-unstable-${sources.silverbullet.revision}";
  src = sources.silverbullet;

  clientBundle = buildNpmPackage {
    pname = "silverbullet-client-bundle";
    inherit (finalAttrs) src version;

    nativeBuildInputs = [ gitMinimal ];

    npmDepsHash = "sha256-EseKAqUJbpIAfJhG1hNlvLgMie/jsXbbVqwea8bEuJQ=";

    buildPhase = ''
      runHook preBuild

      npm run build:plugs # version.json is generated during this phase

      # Override version.json with a deterministic one that does not include
      # build date. Versions on server and client must match otherwise client
      # spams reload messages.

      # Version is just an equality check so the value doesn't matter.
      # https://github.com/silverbulletmd/silverbullet/blob/10bf48dd8c2e32557fb49d5972e8b3dd158271e0/client/client.ts#L1129
      echo '{"version":"${finalAttrs.version}"}' > version.json

      npm run build:client

      runHook postBuild
    '';

    installPhase = ''
      cp -r client_bundle $out
    '';
  };

  preBuild = ''
    echo '{"version":"${finalAttrs.version}"}' > version.json
    ln -s ${finalAttrs.clientBundle} client_bundle
  '';

  cargoHash = "sha256-t2RDrdZsCMReDGUUu3r59OAosZNY3TMlvjo/uM2xL8g=";
  cargoBuildFlags = [
    "-p"
    "silverbullet"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags;

  meta.mainProgram = "silverbullet";
})
