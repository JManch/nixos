{ pkgs
, config
, nixosConfig
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.swww;
  isWayland = lib.fetchers.isWayland config;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
  home.packages = with pkgs; [
    swww
  ];

  impermanence.directories = [
    ".cache/swww"
  ];

  wayland.windowManager.hyprland.settings.exec-once =
    mkIf (config.modules.desktop.windowManager == "hyprland")
      [
        "sleep 1 && ${pkgs.swww}/bin/swww init"
      ];
}
