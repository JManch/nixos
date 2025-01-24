{ pkgs }:
{
  home.packages = [ pkgs.bottles ];

  categoryConfig = {
    gameClasses = [ "steam_proton" ];
    tearingExcludedTitles = [ "Red Dead Redemption" ];
  };

  # Install bottles game prefixes to ~/games
  nsConfig.persistence.directories = [
    ".local/share/bottles"
  ];
}
