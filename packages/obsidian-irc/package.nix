{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  glib,
  cargo-tauri,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  openssl,
  gst_all_1,
  glib-networking,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "obsidian-irc";
  version = "0.3.1-pre";

  src = fetchFromGitHub {
    owner = "ObsidianIRC";
    repo = "ObsidianIRC";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+WwHZTctplPEHa3jdeP5/ovr7gbN9K82R5kGvTnHNtA=";
  };

  patches = [
    ./no-register-all.patch
    ./no-decorations.patch
    # ./env-var-api-keys.patch
    # ./tauri-fetch.patch
  ];

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-c8benovgvfLL8XM3HSAu+Ps6c1YBPSu02OlUP370j4E=";

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src patches;
    hash = "sha256-2uiDil1bjsWGQCFHa1WSiZBp/cNElvh2HNgTpX7st10=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    glib
    gtk3
    webkitgtk_4_1
    glib-networking
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
  ];

  meta = {
    maintainers = with lib.maintainers; [ JManch ];
    license = lib.licenses.gpl3Only;
    mainProgram = "ObsidianIRC";
  };
})
