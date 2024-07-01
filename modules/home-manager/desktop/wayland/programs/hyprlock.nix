{ lib
, pkgs
, inputs
, config
, isWayland
, desktopEnabled
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.programs.hyprlock;
in
mkIf (cfg.enable && desktopEnabled && isWayland) {
  programs.hyprlock = {
    enable = true;
    package = inputs.hyprlock.packages.${pkgs.system}.default;
    # TODO: Configure
  };
}
