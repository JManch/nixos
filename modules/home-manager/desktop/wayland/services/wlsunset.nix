{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe mkForce;
  cfg = config.modules.desktop.services.wlsunset;
  # TODO: Look into this issue
  # WARN: For some reason wlsunset causing system stuttering and graphical
  # artificating during gamma adjustments. If there's a long transition during
  # this means artifacts and freezes appear ~ every 30 seconds. To workaround
  # this we manually set duration to 0 and manually set sunrise and sunset (a
  # requirement for duration=0).
  duration = 0;
  sunrise = "06:00";
  sunset = "21:00";
  temperature = {
    day = 6500;
    night = 4000;
  };
in
mkIf cfg.enable
{
  # WARN: Wlsunset (or any other gamma adjuster) will cause system audio to
  # stutter during gamma adjustments if audio is coming from monitors. This
  # includes using the headphone jack on a monitor.
  services.wlsunset = {
    enable = true;
    # Just to pass assertions
    longitude = "-0.1";
    latitude = "50.8";
  };

  # The hm module is missing duration so we have to do this
  systemd.user.services.wlsunset.Service.ExecStart =
    let
      args = lib.cli.toGNUCommandLineShell { } {
        t = temperature.night;
        T = temperature.day;
        S = sunrise;
        s = sunset;
        d = duration;
      };
    in
    mkForce "${getExe pkgs.wlsunset} ${args}";
}
