{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.wayland.swayidle;
  cfgParent = config.wayland;

  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  lockScript = pkgs.writeShellScript "lock-script" cfgParent.swaylock.lockScript;
  inherit (lib) mkIf;
in
  mkIf (config.desktop.wayland.swayidle.enable) {
    home.packages = with pkgs; [
      procps
    ];

    services.swayidle = {
      enable = true;
      systemdTarget = "hyprland-session.target";
      timeouts = [
        {
          timeout = cfg.lockTime;
          command = lockScript.outPath;
        }
        {
          timeout = cfg.screenOffTime;
          command = "${hyprctl} dispatch dpms off";
          resumeCommand = "${hyprctl} dispatch dpms on";
        }
        (mkIf (cfgParent.swaylock.enable) {
          timeout = cfg.lockedScreenOffTime;
          command = "${pgrep} swaylock && ${hyprctl} dispatch dpms off";
          resumeCommand = "${hyprctl} dispatch dpms on";
        })
      ];
      events = [
        {
          event = "before-sleep";
          command = lockScript.outPath;
        }
      ];
    };
  }
