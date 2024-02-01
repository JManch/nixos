{ lib
, pkgs
, nixosConfig
, ...
}:
let
  cfg = nixosConfig.modules.programs.gaming.steam;
  echo = "${pkgs.coreutils}/bin/echo";
in
lib.mkIf cfg.enable
{
  # Fix slow steam client downloads https://redd.it/16e1l4h
  home.file.".steam/steam/steam_dev.cfg".text = ''
    @nClientDownloadEnableHTTP2PlatformLinux 0
  '';

  programs.zsh.initExtra = /* bash */ ''
    # Takes a screenshot of the primary monitor and calculates the XP-per-second based on results
    drg-xp() {
      local text=$(${pkgs.hyprshot}/bin/hyprshot -m output -m DP-1 -s --raw | ${pkgs.tesseract}/bin/tesseract stdin stdout quiet | ${pkgs.coreutils}/bin/tr '\n' ' ')
      local regex="MISSION TIME: ([0-9]{2}:[0-9]{2})[^0-9]*([0-9]+)"
      local mtime=""
      local xp=""
      if [[ $text =~ $regex ]]; then
        mtime=$match[1]
        xp=$match[2]
      else
        ${echo} "Did not detect DRG mission result screen"
        return 1
      fi
      # Split the time into its components
      IFS=':' read -rA time_c <<< "$mtime"
      local hours=0
      local minutes=0
      local seconds=0
      if [[ ''${#time_c} == 3 ]]; then
        hours=''${time_c[1]}
        minutes=''${time_c[2]}
        seconds=''${time_c[3]}
      elif [[ ''${#time_c} == 2 ]]; then
        minutes=''${time_c[1]}
        seconds=''${time_c[2]}
      else
        ${echo} "Invalid time format"
        return 1
      fi
      local total_seconds=$((hours * 3600 + minutes * 60 + seconds))
      local xp_per_second=$(${echo} "scale=2; $xp / $total_seconds" | ${pkgs.bc}/bin/bc)
      ${echo} "XP per second: $xp_per_second"
    }
  '';
}
