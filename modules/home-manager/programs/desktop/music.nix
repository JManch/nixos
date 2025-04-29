{
  lib,
  pkgs,
  config,
}:
let
  inherit (config.${lib.ns}.desktop) style hyprland;
in
{
  home.packages = with pkgs; [
    picard
    spek
  ];

  ns.desktop.hyprland.settings = {
    workspace = [
      "special:music, gapsin:${toString (style.gapSize * 2)}, gapsout:${toString (style.gapSize * 4)}"
    ];

    bind = [
      "${hyprland.modKey}, S, togglespecialworkspace, music"
      "${hyprland.modKey}SHIFT, S, movetoworkspacesilent, special:music"
    ];

    windowrule = [ "float, class:^(spek)$" ];
  };
}
