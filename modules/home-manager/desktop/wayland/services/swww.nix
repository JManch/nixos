{ lib
, pkgs
, config
, inputs
, nixosConfig
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.swww;
  isWayland = lib.fetchers.isWayland config;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
  wallpapers = inputs.nix-resources.packages.${pkgs.system}.wallpapers;
  swww = "${pkgs.swww}/bin/swww";
  setWallpaperCmd = "${swww} img ${transition} ${config.modules.desktop.wallpaper}";
  primaryMonitor = lib.fetchers.primaryMonitor nixosConfig;
  refreshRate = "${builtins.toString (builtins.floor primaryMonitor.refreshRate)}";
  transition = "--transition-type center --transition-step 90 --transition-fps ${refreshRate}";
in
mkIf (osDesktopEnabled && isWayland) {

  home.packages = [ pkgs.swww ];

  impermanence.directories = [
    ".cache/swww"
  ];

  wayland.windowManager.hyprland.settings.exec-once =
    mkIf (config.modules.desktop.windowManager == "hyprland")
      [
        "sleep 1 && ${swww} init --no-cache && ${setWallpaperCmd}"
      ];

  home.activation."swww-set-wallpaper" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${setWallpaperCmd}
  '';
}
