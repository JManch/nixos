{ lib, pkgs }:
{
  home.packages = lib.singleton (
    pkgs.wrapOBS.override { obs-studio = pkgs.obs-studio; } {
      plugins = [ pkgs.obs-studio-plugins.obs-pipewire-audio-capture ];
    }
  );

  ns.persistence.directories = [ ".config/obs-studio" ];
}
