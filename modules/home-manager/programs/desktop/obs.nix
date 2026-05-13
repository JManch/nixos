{ lib, pkgs }:
{
  home.packages = lib.singleton (
    pkgs.wrapOBS.override { obs-studio = pkgs.obs-studio; } {
      plugins = with pkgs.obs-studio-plugins; [
        obs-pipewire-audio-capture
        obs-plugin-countdown
      ];
    }
  );

  ns.persistence.directories = [ ".config/obs-studio" ];
}
