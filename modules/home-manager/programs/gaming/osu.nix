{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.gaming.osu;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.osu-lazer-bin ];

  ${ns}.programs.gaming.gameClasses = [
    "osu!"
  ];

  persistence.directories = [
    ".local/share/osu"
  ];
}
