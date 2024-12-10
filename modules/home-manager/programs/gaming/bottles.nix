{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${lib.ns}.programs.gaming.bottles;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.bottles ];

  ${lib.ns}.programs.gaming = {
    gameClasses = [ "steam_proton" ];
    tearingExcludedTitles = [ "Red Dead Redemption" ];
  };

  # Install bottles game prefixes to ~/games
  persistence.directories = [
    ".local/share/bottles"
  ];
}
