{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.winbox;
in
lib.mkIf cfg.enable
{
  # NOTE: If Winbox stops working, deleting the ~/.local/share/winbox/wine
  # directory tends to fix it

  programs.winbox = {
    enable = true;
    package = pkgs.winbox.override {
      wine = config.modules.programs.wine.package;
    };
    openFirewall = true;
  };

  persistenceHome.directories = [ ".local/share/winbox" ];
}
