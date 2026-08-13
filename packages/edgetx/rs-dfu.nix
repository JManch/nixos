{
  stdenv,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "rs-dfu";
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "EdgeTX";
    repo = "rs-dfu";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9PybXRRgqDf0u8o34IWZRuWWTsjPuZr1Sq8aPD/kxng=";
  };

  cargoHash = "sha256-gPNrso7OPt553u2S1k9rwhlwa/tu55AncU4MyqOEhP8=";
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
