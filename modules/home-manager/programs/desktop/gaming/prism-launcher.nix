{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns mkIf;
in
{
  home.packages = [ pkgs.prismlauncher ];
  categoryConfig.gameClasses = [ "Minecraft.*" ];

  ns = {
    firewall.interfaces = mkIf (lib.${ns}.wgInterfaceEnabled "friends" osConfig) {
      wg-friends.allowedTCPPorts = [ 25565 ];
    };

    persistence.directories = [ ".local/share/PrismLauncher" ];
  };
}
