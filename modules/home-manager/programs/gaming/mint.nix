{ lib, config, ... }@args:
let
  inherit (lib) ns mkIf getExe;
  cfg = config.${ns}.programs.gaming.mint;
  mint = (lib.${ns}.flakePkgs args "mint").default;
in
mkIf cfg.enable {
  home.packages = [ mint ];

  xdg.desktopEntries.mint = {
    name = "Mint";
    genericName = "Mod Loader";
    exec = "${getExe mint}";
    terminal = false;
    type = "Application";
    icon = "applications-games";
    categories = [ "Game" ];
  };

  backups.mint.paths = [ ".config/mint" ];

  persistence.directories = [ ".config/mint" ];
}
