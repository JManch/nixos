{ pkgs }:
{
  home.packages = [ pkgs.foliate ];
  nsConfig.persistence.directories = [
    ".local/share/com.github.johnfactotum.Foliate"
    # Book covers do not show if cache is deleted
    ".cache/com.github.johnfactotum.Foliate"
  ];
}
