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
    # unit since it wants the main PID to be killed first
    desktop.uwsm.appUnitOverrides."anki@.service" = ''
      [Service]
      KillMode=mixed
    '';

    desktop.hyprland.settings.windowrule = [
      "match:class anki, match:float true, center true"
      # The browse window's initial title is Anki before switching to Browse.*
      "match:class anki, match:title Anki, float true, size monitor_w*0.75 monitor_h*0.75, center true"
    ];
  };
}
