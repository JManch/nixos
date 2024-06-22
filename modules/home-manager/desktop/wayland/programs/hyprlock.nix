{ lib
, pkgs
, inputs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers;
  cfg = config.modules.desktop.programs.hyprlock;
  isWayland = fetchers.isWayland osConfig;
in
mkIf (cfg.enable && isWayland) {
  programs.hyprlock = {
    enable = true;
    package = inputs.hyprlock.packages.${pkgs.system}.default;
    # TODO: Configure
  };
}
