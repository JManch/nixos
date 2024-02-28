{ lib, pkgs, osConfig, ... }:
let
  inherit (lib) mkIf getExe getExe' fetchers;
  cfg = osConfig.modules.programs.gaming.steam;
in
mkIf cfg.enable
{
  # Fix slow steam client downloads https://redd.it/16e1l4h
  home.file.".steam/steam/steam_dev.cfg".text = ''
    @nClientDownloadEnableHTTP2PlatformLinux 0
  '';

  modules.programs.gaming.windowClassRegex = [
    "steam_app.*"
    "cs2"
  ];

  programs.zsh.initExtra =
    let
      hyprshot = getExe pkgs.hyprshot;
      tesseract = getExe pkgs.tesseract;
      tr = getExe' pkgs.coreutils "tr";
      bc = getExe' pkgs.bc "bc";
      primaryMonitor = fetchers.primaryMonitor osConfig;
    in
      /* bash */ ''

    # Takes a screenshot of the primary monitor and calculates the XP-per-second based on results
    drg-xp() {

      text=$(${hyprshot} -m output -m ${primaryMonitor.name} -s --raw | ${tesseract} stdin stdout quiet | ${tr} '\n' ' ')
      regex="MISSION TIME: ([0-9]{2}:[0-9]{2})[^0-9]*([0-9]+)"
      mtime=""
      xp=""
      if [[ $text =~ $regex ]]; then
        mtime=$match[1]
        xp=$match[2]
      else
        echo "Did not detect DRG mission result screen"
        return 1
      fi
      # Split the time into its components
      IFS=':' read -rA time_c <<< "$mtime"
      hours=0
      minutes=0
      seconds=0
      if [[ ''${#time_c} == 3 ]]; then
        hours=''${time_c[1]}
        minutes=''${time_c[2]}
        seconds=''${time_c[3]}
      elif [[ ''${#time_c} == 2 ]]; then
        minutes=''${time_c[1]}
        seconds=''${time_c[2]}
      else
        echo "Invalid time format"
        return 1
      fi
      total_seconds=$((hours * 3600 + minutes * 60 + seconds))
      xp_per_second=$(echo "scale=2; $xp / $total_seconds" | ${bc})
      echo "XP per second: $xp_per_second"

    }

  '';

  desktop.hyprland.settings.windowrulev2 = [
    # Main steam window
    "workspace 5,class:^(steam)$,title:^(Steam)$"

    # Steam sign-in window
    "noinitialfocus,class:^(steam)$,title:^(Sign in to Steam)$"
    "workspace 5 silent,class:^(steam)$,title:^(Sign in to Steam)$"

    # Friends list
    "float,class:^(steam)$,title:^(Friends List)$"
    "size 360 700,class:^(steam)$,title:^(Friends List)$"
    "center,class:^(steam)$,title:^(Friends List)$"
  ];
}
