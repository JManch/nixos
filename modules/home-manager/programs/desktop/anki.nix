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

    desktop.hyprland.extraConf = # lua
      ''
        hl.window_rule({ match = { class = "anki", float = true }, center = true })
        -- The browse window's initial title is Anki before switching to Browse.*
        hl.window_rule({ match = { class = "anki", title = "Anki" }, workspace = "emptym" })
      '';
  };
}
