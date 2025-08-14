{ pkgs }:
{
  home.packages = [ pkgs.chromium ];

  # Chromium moves its main PID to another scope so we need to run as a
  # service for proper shutdown
  # https://github.com/hyprwm/Hyprland/discussions/8459#discussioncomment-14063563
  ns.desktop.uwsm.serviceApps = [ "chromium-browser" ];

  ns.persistence.directories = [ ".config/chromium" ];
}
