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
  swaylockCfg = desktopCfg.swaylock;
  isWayland = lib.fetchers.isWayland config;
  sessionTarget = lib.fetchers.getDesktopSessionTarget config;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;

  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
  home.packages = with pkgs; [
    procps # provides pgrep
    sway-audio-idle-inhibit
  ];

  services.swayidle = {
    enable = true;
    systemdTarget = sessionTarget;
    timeouts = [
      {
        timeout = cfg.lockTime;
        command = swaylockCfg.lockScript;
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
        command = swaylockCfg.lockScript;
      }
    ];
  };

  systemd.user.services.sway-audio-idle-inhibit = {
    Unit = {
      Description = "Prevents swayidle from sleeping while any application is outputting or receiving audio";
      After = [ "swayidle.service" ];
      Requires = [ "swayidle.service" ];
    };

    Service = {
      Restart = "always";
      RestartSec = 3;
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
    };

    Install = {
      WantedBy = [ sessionTarget ];
    };
  };
}
