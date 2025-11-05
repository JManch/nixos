{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) ns mkIf;
  inherit (osConfig.${ns}.system.networking) wireless;
in
{
  enableOpt = false;
  conditions = [
    wireless.enable
    (wireless.backend == "iwd")
  ];

  home.packages = [ pkgs.impala ];

  xdg.desktopEntries.impala = mkIf config.${ns}.desktop.enable {
    name = "impala";
    genericName = "Wifi Manager";
    exec = "xdg-terminal-exec --title=impala --app-id=impala impala";
    terminal = false;
    type = "Application";
    icon = "application-x-generic";
    categories = [ "System" ];
  };

  ns.desktop.hyprland.settings.windowrule = [
    "float, class:^(impala)$"
    "size 60% 50%, class:^(impala)$"
    "center, class:^(impala)$"
  ];
}
