{ pkgs
, config
, osConfig
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.swayidle;
  cfgParent = config.modules.desktop;
  isWayland = lib.validators.isWayland osConfig;

  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  lockScript = pkgs.writeShellScript "lock-script" cfgParent.swaylock.lockScript;
in
mkIf (isWayland && cfg.enable) {
  home.packages = with pkgs; [
    procps
  ];

  services.swayidle = {
    enable = true;
    systemdTarget = config.modules.desktop.sessionTarget;
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

  desktop.hyprland.binds =
    let
      mod = config.modules.desktop.hyprland.modKey;
    in
    [
      "${mod}, Space, exec, ${lockScript.outPath}"
    ];
}
