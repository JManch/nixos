{ pkgs }:
{
  home.packages = [ pkgs.anki-bin ];
  systemd.user.sessionVariables.ANKI_WAYLAND = 1;

  ns = {
    backups.anki = {
      backend = "restic";
      paths = [ ".local/share/Anki2" ];
    };

    persistence.directories = [ ".local/share/Anki2" ];
  };
}
