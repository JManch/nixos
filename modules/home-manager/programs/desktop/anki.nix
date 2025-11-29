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

    desktop.hyprland.settings.windowrule = [
      "match:class anki, match:float true, center true"
      "match:class anki, match:title Browse.*, float true, size monitor_w*0.75 monitor_h*0.75, center true"
    ];
  };
}
