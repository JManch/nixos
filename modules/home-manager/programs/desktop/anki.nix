{ pkgs }:
{
  home = {
    packages = [ pkgs.anki-bin ];
    sessionVariables.ANKI_WAYLAND = 1;
  };

  ns = {
    backups.anki.paths = [ ".local/share/Anki2" ];
    persistence.directories = [ ".local/share/Anki2" ];
  };
}
