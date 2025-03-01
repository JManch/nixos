{ pkgs }:
{
  # Unity is unusable, at least on Hyprland. Constant crashing. I suspect it's
  # due to some dbus or xwayland issues but idk? The logs are pretty useless.
  home.packages = [ pkgs.unityhub ];

  ns.persistence.directories = [
    "Unity" # yuck
    ".config/unity3d"
    ".local/share/unity3d"
    ".config/unityhub"
  ];
}
