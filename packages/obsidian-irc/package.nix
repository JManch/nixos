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
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "ObsidianIRC";
    repo = "ObsidianIRC";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6wDD6wth8qyNSQRCMGLBxjvstLAuZsbDwaHWJwjR3Ck=";
  };

  patches = [
    ./no-register-all.patch
    ./no-decorations.patch
    ./env-var-api-keys.patch
    ./tauri-fetch.patch
  ];

  # Patches don't apply to lock files so we need to vendor the patched file
  cargoLock.lockFile = ./Cargo.lock;
  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src patches;
    hash = "sha256-NFuFsJ4bnSUTPRhsUpnptfNHHaQSQB7zQX/5UKxc/rQ=";
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
