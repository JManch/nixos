# WARN: For some reason wlsunset causing system stuttering and graphical
# artificating during gamma adjustments. If there's a long transition during
# this means artifacts and freezes appear ~ every 30 seconds. To workaround
# this we have an option to disable transitioning by setting duration to 0
#
# WARN: Wlsunset (or any other gamma adjuster) will cause system audio to
# stutter during gamma adjustments if audio is coming from monitors. This
# includes using the headphone jack on a monitor.
{
  lib,
  pkgs,
  config,
  isWayland,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    optionalAttrs
    cli
    ;
  cfg = config.modules.desktop.services.wlsunset;
in
mkIf (cfg.enable && isWayland) {
  # We don't use the home-manager module because it's missing options
  systemd.user.services.wlsunset = {
    Unit = {
      Description = "Day/night gamma adjustments for Wayland compositors";
      PartOf = [ "graphical-session.target" ];
    };

    Service.ExecStart =
      let
        args = cli.toGNUCommandLineShell { } (
          {
            t = 4000; # temp night
            T = 6500; # temp day
          }
          // optionalAttrs cfg.transition {
            l = 50.8; # latitude
            L = -0.1; # longitude
          }
          // optionalAttrs (!cfg.transition) {
            d = 0; # duration
            # Duration 0 requires manual sunrise/sunset times
            S = "06:00"; # sunrise
            s = "21:00"; # sunset
          }
        );
      in
      "${getExe pkgs.wlsunset} ${args}";

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
