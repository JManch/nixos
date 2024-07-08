{ lib
, pkgs
, config
, osConfig'
, ...
}:
let
  inherit (lib) mkIf utils;
  cfg = config.modules.programs.gaming.prism-launcher;
in
mkIf cfg.enable
{
  home.packages = [ pkgs.prismlauncher ];

  modules.programs.gaming.gameClasses = [ "Minecraft.*" ];

  firewall.interfaces = mkIf (utils.wgInterfaceEnabled "friends" osConfig') {
    wg-friends.allowedTCPPorts = [ 25565 ];
  };

  persistence.directories = [ ".local/share/PrismLauncher" ];
}
