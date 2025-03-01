{ pkgs }:
{
  home.packages = [ pkgs.foliate ];
  ns.persistence.directories = [
    ".local/share/com.github.johnfactotum.Foliate"
    # Book covers do not show if cache is deleted
    ".cache/com.github.johnfactotum.Foliate"
  ];
}
