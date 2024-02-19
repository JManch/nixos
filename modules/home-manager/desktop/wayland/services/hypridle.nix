{ lib, pkgs, inputs, config, ... }:
let
  inherit (lib) mkIf;
  cfg = desktopCfg.services.hypridle;
  desktopCfg = config.modules.desktop;
  swaylock = desktopCfg.programs.swaylock;
in
{
  imports = [
    inputs.hypridle.homeManagerModules.default
  ];

  config = mkIf (cfg.enable && swaylock.enable) {
    services.hypridle = {
      enable = true;
      lockCmd = swaylock.lockScript;
      ignoreDbusInhibit = false;

      listeners =
        let
          sleep = "${pkgs.coreutils}/bin/sleep";
          hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
        in
        [
          {
            timeout = cfg.lockTime;
            onTimeout = swaylock.lockScript;
          }
          {
            timeout = cfg.screenOffTime - 1;
            onTimeout = "${sleep} 1 && ${hyprctl} dispatch dpms off";
          }
        ];
    };
  };
}
