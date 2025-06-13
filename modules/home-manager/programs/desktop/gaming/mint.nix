{ lib, args }:
let
  inherit (lib) ns getExe;
  mint = (lib.${ns}.flakePkgs args "mint").default;
in
{
  home.packages = [ mint ];

  xdg.desktopEntries.mint = {
    name = "Mint";
    genericName = "Mod Loader";
    exec = getExe mint;
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
