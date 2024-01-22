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
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;

  pgrep = "${pkgs.procps}/bin/pgrep";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
in
mkIf (osDesktopEnabled && isWayland && cfg.enable) {
  home.packages = with pkgs; [
    sway-audio-idle-inhibit
  ];

  services.swayidle = {
    enable = true;
    timeouts = [
      (lib.mkIf desktopCfg.swaylock.enable {
        timeout = cfg.lockTime;
        command = "${pgrep} -x swaylock || ${swaylockCfg.lockScript}";
      })
      {
        timeout = cfg.screenOffTime;
        # TODO: Modularise the monitor off command (shouldn't just be hyprland)
        command = "${hyprctl} dispatch dpms off";
        resumeCommand = "${hyprctl} dispatch dpms on";
      }
    ];
    events = [
      {
        event = "before-sleep";
        command = swaylockCfg.lockScript;
      }
    ];
  };

  # TODO: Fix inhibit always being active when spotify_player is open
  # (regardless of whether or not music is playing)
  systemd.user.services.sway-audio-idle-inhibit = {
    Unit = {
      Description = "Prevents swayidle from sleeping while any application is outputting or receiving audio";
      After = [ "swayidle.service" ];
      Requires = [ "swayidle.service" ];
      X-SwitchMethod = "keep-old";
    };

    Service = {
      Restart = "always";
      RestartSec = 10;
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
