{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf;
  inherit (osConfig.modules.services) wireguard;
  cfg = config.modules.programs.gaming.prism-launcher;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.prismlauncher ];

  modules.programs.gaming.gameClasses = [ "Minecraft.*" ];

  firewall.interfaces.wg-friends.allowedTCPPorts = mkIf wireguard.friends.enable
    [ 25565 ];

  persistence.directories = [ ".local/share/PrismLauncher" ];
}
