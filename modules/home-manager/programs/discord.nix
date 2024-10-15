{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.discord;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    discord
    (vesktop.override { withMiddleClickScroll = true; })
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
  ];

  persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
