{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns mkIf;
in
{
  home.packages = [
    (pkgs.prismlauncher.override {
      jdks = with pkgs; [
        jdk21
        jdk17
        jdk8
        jdk25
      ];
    })
  ];
  categoryConfig.gameClasses = [ "Minecraft.*" ];

  ns = {
    firewall.interfaces = mkIf (lib.${ns}.wgInterfaceEnabled "friends" osConfig) {
      wg-friends.allowedTCPPorts = [ 25565 ];
    };

    persistence.directories = [ ".local/share/PrismLauncher" ];
  };
}
