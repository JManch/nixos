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
    webcord
    discord-screenaudio
  ];

  impermanence.directories = [
    ".config/WebCord"
    ".config/discord"
  ];
}
