{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.winbox;
in
lib.mkIf cfg.enable {
  # New native linux version
  userPackages = [ pkgs.winbox4 ];

  # NOTE: If Winbox stops working, deleting the ~/.local/share/winbox/wine
  # directory tends to fix it
  programs.winbox = {
    enable = true;
    package = pkgs.winbox.override { wine = config.${ns}.programs.wine.package; };
    openFirewall = true;
  };

  persistenceHome.directories = [
    ".local/share/winbox"
    ".local/share/MikroTik" # v4 directory
  ];
}
