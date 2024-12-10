{
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib) ns mkIf;
  cfg = config.${ns}.programs.gaming.prism-launcher;
in
mkIf cfg.enable {
  home.packages = [ pkgs.prismlauncher ];

  ${ns}.programs.gaming.gameClasses = [ "Minecraft.*" ];

  firewall.interfaces = mkIf (lib.${ns}.wgInterfaceEnabled "friends" osConfig') {
    wg-friends.allowedTCPPorts = [ 25565 ];
  };

  persistence.directories = [ ".local/share/PrismLauncher" ];
}
