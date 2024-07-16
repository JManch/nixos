{
  vesktop,
  pnpm,
  fetchFromGitHub,
  autoPatchelfHook,
  copyDesktopItems,
  makeWrapper,
  nodejs,
  ...
}:
vesktop.overrideAttrs (oldAttrs: rec {
  pname = "vesktop";
  version = "1.5.3";

  src = fetchFromGitHub {
    owner = "Vencord";
    repo = "Vesktop";
    rev = "v${version}";
    hash = "sha256-HlT7ddlrMHG1qOCqdaYjuWhJD+5FF1Nkv2sfXLWd07o=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit
      pname
      version
      src
      patches
      ;
    hash = "sha256-rizJu6v04wFEpJtakC2tfPg/uylz7gAOzJiXvUwdDI4=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    nodejs
    pnpm.configHook
  ];

  patches = [ ../patches/vesktop.patch ];
})
