{
  lib,
  args,
  pkgs,
}:
let
  mint = (lib.${lib.ns}.flakePkgs args "mint").default;
in
{
  home.packages = [
    (lib.${lib.ns}.addPatches mint [
      "mint-crash-fix.patch"
      (pkgs.fetchpatch2 {
        url = "https://github.com/trumank/mint/commit/0170376189d46fc8f7b627f8ee0dcdf7b0b2c2ad.patch";
        hash = "sha256-UHbRZ033mf8iUm6kOrPzA5PloV2/wcv1Nq/rL3tsJm8=";
      })
    ])
  ];

  xdg.desktopEntries.mint = {
    name = "Mint";
    genericName = "Mod Loader";
    exec = "mint";
    terminal = false;
    type = "Application";
    icon = "applications-games";
    categories = [ "Game" ];
  };

  ns = {
    backups.mint = {
      backend = "restic";
      paths = [ ".config/mint" ];
    };

    persistence.directories = [ ".config/mint" ];
  };
}
