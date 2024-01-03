{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.modules.programs.discord;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    discord
  ];

  impermanence.directories = [
    ".config/discord"
  ];
}
