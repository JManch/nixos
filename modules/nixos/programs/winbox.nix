{
  lib,
  pkgs,
  config,
  selfPkgs,
  ...
}:
let
  cfg = config.modules.programs.winbox;
in
lib.mkIf cfg.enable {
  # New v4 native linux version
  userPackages = [ selfPkgs.winbox ];

  # NOTE: If Winbox stops working, deleting the ~/.local/share/winbox/wine
  # directory tends to fix it
  programs.winbox = {
    enable = true;
    package = pkgs.winbox.override { wine = config.modules.programs.wine.package; };
    openFirewall = true;
  };

  persistenceHome.directories = [
    ".local/share/winbox"
    ".local/share/MikroTik" # v4 directory
  ];
}
