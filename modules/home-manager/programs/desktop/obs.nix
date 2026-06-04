{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns singleton;
  package =
    if osConfig.${ns}.core.device.gpu.type == "nvidia" then
      pkgs.obs-studio.override {
        cudaSupport = true;
      }
    else
      pkgs.obs-studio;
in
{
  home.packages = singleton (
    pkgs.wrapOBS.override { obs-studio = package; } {
      plugins = with pkgs.obs-studio-plugins; [
        obs-pipewire-audio-capture
        obs-plugin-countdown
      ];
    }
  );

  ns.persistence.directories = [ ".config/obs-studio" ];
}
