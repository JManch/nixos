{
  scopePkgs,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "silverbullet-cli";
  inherit (scopePkgs.silverbullet)
    version
    src
    cargoHash
    clientBundle
    preBuild
    ;

  cargoBuildFlags = [ "-p sb" ];
  meta.mainProgram = "cli";
})
