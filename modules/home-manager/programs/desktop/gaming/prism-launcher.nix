{ pkgs }:
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

  ns.persistence.directories = [ ".local/share/PrismLauncher" ];
}
