{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.gaming.prism-launcher;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.prismlauncher ];

  modules.programs.gaming.windowClassRegex = [ "Minecraft.*" ];

  persistence.directories = [ ".local/share/PrismLauncher" ];
}
