{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.discord;
in
lib.mkIf cfg.enable
{
  home.packages = [
    pkgs.discord
    (pkgs.vesktop.override {
      withMiddleClickScroll = true;
    })
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, class:^(vesktop|discord)$, title:^(Discord.*)$"
  ];

  persistence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
