{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.wine;
in
lib.mkIf cfg.enable
{
  environment.systemPackages = with pkgs; [
    # Support 64 bit only
    # Unstable native wayland support
    (wine-wayland.override { wineBuild = "wine64"; })

    # Helper for installing runtime libs
    winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
