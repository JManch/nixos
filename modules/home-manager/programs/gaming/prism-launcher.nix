{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.gaming.prism-launcher;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.prismlauncher ];

  modules.programs.gaming.gameClasses = [ "Minecraft.*" ];

  firewall.interfaces.wg-discord.allowedTCPPorts = [ 25565 ];

  persistence.directories = [ ".local/share/PrismLauncher" ];
}
