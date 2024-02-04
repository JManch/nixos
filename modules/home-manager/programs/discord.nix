{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.discord;
  desktopCfg = config.modules.desktop;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    discord
    vesktop
  ];

  desktop.hyprland.settings = lib.mkIf (desktopCfg.windowManager == "hyprland") {
    windowrulev2 = [
      "noinitialfocus,class:^(vesktop|discord)$"
      "workspace 4 silent,class:^(vesktop|discord)$"
    ];
  };

  impermanence.directories = [
    ".config/discord"
    ".config/vesktop"
  ];
}
