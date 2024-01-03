{ pkgs
, config
, nixosConfig
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.swww;
  isWayland = lib.validators.isWayland nixosConfig;
in
mkIf (isWayland && cfg.enable) {
  home.packages = with pkgs; [
    swww
  ];

  impermanence.directories = [
    ".cache/swww"
  ];

  wayland.windowManager.hyprland.settings.exec-once =
    mkIf (nixosConfig.usrEnv.desktop.compositor == "hyprland")
      [
        "sleep 1 && ${pkgs.swww}/bin/swww init"
      ];
}
