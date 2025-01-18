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
  osConfig,
  isWayland,
  ...
}:
let
  inherit (lib) ns mkIf getExe;
  cfg = config.${ns}.desktop.services.wlsunset;
  latitude = "50.8";
  longitude = "-0.1";
in
mkIf (cfg.enable && isWayland) {
  # We don't use the home-manager module because it's missing options
  systemd.user.services.wlsunset = {
    Unit = {
      Description = "Day/night gamma adjustments for Wayland compositors";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service.Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
    Service.ExecStart =
      let
        args = "-t 4000 -T 6500";
        wlsunset = getExe pkgs.wlsunset;
        sunwait = getExe pkgs.sunwait;
        grep = getExe pkgs.gnugrep;
      in
      if cfg.transition then
        "${wlsunset} ${args} -l ${latitude} -L ${longitude}"
      else
        # If starting in no-transition mode we have to calculate the sunrise
        # and sunset times ourselves because duration=0 only works with manual
        # sunrise and sunset times
        (pkgs.writeShellScript "wlsunset-manual-sun-times" ''
          line=$(
            ${sunwait} report offset 30 ${latitude}N ${longitude}E \
            | ${grep} 'twilight & offset')

          sunrise=$(echo "$line" | awk '{print $6}')
          sunset=$(echo "$line" | awk '{print $8}')

          exec ${wlsunset} ${args} -d 0 -S "$sunrise" -s "$sunset"
        '');

    Install.WantedBy = [ "graphical-session.target" ];
  };

  # wlsunset sometimes doesn't work after DPMS, restarting fixes it
  ${ns}.desktop.programs.locker.postUnlockScript = "systemctl restart --user wlsunset";
}
