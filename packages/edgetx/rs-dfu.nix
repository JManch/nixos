{
  stdenv,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rs-dfu";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "EdgeTX";
    repo = "rs-dfu";
    tag = "v${finalAttrs.version}";
    hash = "sha256-yCicPBfA4uQXJbUJ95spXJtq4oxaYbGObRmEd+STN/U=";
  };

  cargoHash = "sha256-D8JMzwjtHjR3iqDvtMvMANMOz7u3yc2sWlZ4YMWUuEA=";
  cargoBuildFlags = [ "--all" ];

  installPhase =
    let
      inherit (stdenv.hostPlatform.rust) cargoShortTarget;
    in
    ''
      sh ./package.sh ${cargoShortTarget} "target/${cargoShortTarget}"
      cp -r dist $out
    '';
})
