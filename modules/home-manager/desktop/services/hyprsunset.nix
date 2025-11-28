{
  lib,
  args,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) ns getExe;
in
{
  xdg.configFile."hypr/hyprsunset.conf".text = ''
    profile {
      time = 7:00
      temperature = 4000
    }

    profile {
      time = 8:00
      temperature = 5000
    }

    profile {
      time = 9:00
      temperature = 6000
    }

    profile {
      time = 10:00
      identity = true
    }

    profile {
      time = 20:00
      temperature = 6000
    }

    profile {
      time = 21:00
      temperature = 5000
    }

    profile {
      time = 22:00
      temperature = 4000
    }

    profile {
      time = 23:00
      temperature = 3000
    }
  '';

  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "An application to enable a blue-light filter on Hyprland.";
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = getExe (lib.${ns}.flakePkgs args "hyprsunset").hyprsunset;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  ns.desktop.hyprland.settings =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;

      modifyGamma = pkgs.writeShellScript "hypr-modify-gamma" ''
        current=$(hyprctl hyprsunset gamma)
        new=$(${getExe pkgs.gawk} -v num="$current" -v mod="$1" 'BEGIN {
          rounded = (5 * sprintf("%.0f", num / 5)) + mod;
          if (rounded < 0) bounded = 0;
          else if (rounded > 100) bounded = 100;
          else bounded = rounded;
          print bounded;
        }')
        # Not using the hyprsunset increment/decrement functionality because it has rounding issues
        hyprctl hyprsunset gamma "$new"
        ${getExe pkgs.libnotify} --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Gamma $new%"
      '';

      resetGamma = pkgs.writeShellScript "hypr-reset-gamma" ''
        hyprctl hyprsunset reset gamma
        ${getExe pkgs.libnotify} --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Gamma reset to $(hyprctl hyprsunset gamma)%"
      '';

      modifyTemperature = pkgs.writeShellScript "hypr-modify-temperature" ''
        hyprctl hyprsunset temperature "$1"
        ${getExe pkgs.libnotify} --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Temperature $(hyprctl hyprsunset temperature)K"
      '';

      resetTemperature = pkgs.writeShellScript "hypr-reset-temperature" ''
        hyprctl hyprsunset reset temperature
        ${getExe pkgs.libnotify} --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Temperature reset to $(hyprctl hyprsunset temperature)K"
      '';

    in
    {
      bind = [
        "${modKey}, XF86MonBrightnessUp, exec, ${modifyGamma} 5"
        "${modKey}, F8, exec, ${modifyGamma} 5"
        "${modKey}, XF86MonBrightnessDown, exec, ${modifyGamma} -5"
        "${modKey}, F7, exec, ${modifyGamma} -5"
        "${modKey}SHIFT, XF86MonBrightnessUp, exec, ${modifyTemperature} +200"
        "${modKey}SHIFT, F8, exec, ${modifyTemperature} +200"
        "${modKey}SHIFT, XF86MonBrightnessDown, exec, ${modifyTemperature} -200"
        "${modKey}SHIFT, F7, exec, ${modifyTemperature} -200"
      ];

      bindo = [
        # Reset with long press
        "${modKey}, XF86MonBrightnessUp, exec, ${resetGamma}"
        "${modKey}, F8, exec, ${resetGamma}"
        "${modKey}, XF86MonBrightnessDown, exec, ${resetGamma}"
        "${modKey}, F7, exec, ${resetGamma}"
        "${modKey}SHIFT, XF86MonBrightnessUp, exec, ${resetTemperature}"
        "${modKey}SHIFT, F8, exec, ${resetTemperature}"
        "${modKey}SHIFT, XF86MonBrightnessDown, exec, ${resetTemperature}"
        "${modKey}SHIFT, F7, exec, ${resetTemperature}"
      ];
    };

  ns.desktop.programs.locker.postUnlockScript =
    "${lib.getExe' pkgs.hyprland "hyprctl"} hyprsunset reset gamma";
}
