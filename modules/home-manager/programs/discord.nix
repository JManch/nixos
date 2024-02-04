{ config
, inputs
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
    vesktop
  ];

  impermanence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
