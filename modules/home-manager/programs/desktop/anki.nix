{ pkgs }:
{
  home.packages = [ pkgs.anki ];

  ns = {
    backups.anki = {
      backend = "restic";
      paths = [ ".local/share/Anki2" ];
    };

    persistence.directories = [ ".local/share/Anki2" ];

    # If the add card window is open anki hangs when attemping to stop the
    # unit. SIGKILL after 10 secs instead of default 90 secs.
    desktop.uwsm.appUnitOverrides."anki@.service" = ''
      [Service]
      TimeoutStopSec=10
    '';
  };
}
