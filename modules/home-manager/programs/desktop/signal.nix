{ pkgs }:
{
  home.packages = [ pkgs.signal-desktop ];

  ns.persistence.directories = [ ".config/Signal" ];
}
