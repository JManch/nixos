{
  ns,
  lib,
  config,
  ...
}@args:
let
  cfg = config.${ns}.programs.gaming.mint;
  mint = (lib.${ns}.flakePkgs args "mint").default;
in
lib.mkIf cfg.enable {
  home.packages = [ mint ];

  xdg.desktopEntries.mint = {
    name = "Mint";
    genericName = "Mod Loader";
    exec = "mint";
    terminal = false;
    type = "Application";
    icon = "applications-games";
    categories = [ "Game" ];
  };

  backups.mint.paths = [ ".config/mint" ];

  persistence.directories = [ ".config/mint" ];
}
