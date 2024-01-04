{ pkgs
, config
, nixosConfig
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.modules.desktop.swayidle;
  desktopCfg = config.modules.desktop;
  isWayland = lib.fetchers.isWayland config;
  sessionTarget = lib.fetchers.getDesktopSessionTarget config;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;

  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  lockScript = pkgs.writeShellScript "lock-script" desktopCfg.swaylock.lockScript;
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
  home.packages = with pkgs; [
    procps
  ];

  services.swayidle = {
    enable = true;
    systemdTarget = sessionTarget;
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
      (mkIf (desktopCfg.swaylock.enable) {
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
    mkIf (config.modules.desktop.windowManager == "hyprland")
      [
        "${mod}, Space, exec, ${lockScript.outPath}"
      ];
}
