{
  lib,
  cfg,
  pkgs,
  config,
  username,
}:
{
  opts.graphical = lib.mkEnableOption "Wireshark GUI";

  asserts = [
    (cfg.graphical -> config.${lib.ns}.system.desktop.enable)
    "Wireshark GUI requires system.desktop to be enabled"
  ];

  programs.wireshark = {
    enable = true;
    package = if cfg.graphical then pkgs.wireshark-qt else pkgs.wireshark-cli;
  };

  users.users.${username}.extraGroups = [ "wireshark" ];
}
