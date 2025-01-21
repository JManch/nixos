{
  lib,
  pkgs,
  config,
  osConfig,
  desktopEnabled,
  ...
}:
let
  inherit (lib) ns mkIf getExe;
  inherit (lib.${ns}) asserts sliceSuffix;
  inherit (osConfig.${ns}.device) primaryMonitor backlight;
  cfg = config.${ns}.desktop.services.wluma;
in
mkIf (cfg.enable && desktopEnabled) {
  assertions = asserts [
    (backlight != null)
    "wluma requires the device to have a backlight"
  ];

  xdg.configFile."wluma/config.toml".text = ''
    [als.iio]
    path = "/sys/bus/iio/devices"
    thresholds = { 0 = "night", 20 = "dark", 80 = "dim", 250 = "normal", 500 = "bright", 800 = "outdoors" }

    [[output.backlight]]
    name = "${primaryMonitor.name}"
    path = "/sys/class/backlight/${backlight}"
    capturer = "wayland"
  '';

  systemd.user.services.wluma = {
    Unit = {
      Description = "Screen Brightness Adjuster";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${sliceSuffix osConfig}.slice";
      ExecStart = getExe pkgs.wluma;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  persistence.directories = [ ".local/share/wluma" ];
}
