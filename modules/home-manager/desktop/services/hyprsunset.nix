{
  lib,
  args,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) ns getExe;
  inherit (lib.${ns}) mkHyprBind mkHyprExec;
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

  ns.desktop.hyprland.binds =
    let
      notify-send = getExe pkgs.libnotify;

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
        ${notify-send} --transient --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Gamma $new%"
      '';

      resetGamma = pkgs.writeShellScript "hypr-reset-gamma" ''
        hyprctl hyprsunset reset gamma
        ${notify-send} --transient --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Gamma reset to $(hyprctl hyprsunset gamma)%"
      '';

      modifyTemperature = pkgs.writeShellScript "hypr-modify-temperature" ''
        hyprctl hyprsunset temperature "$1"
        ${notify-send} --transient --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Temperature $(hyprctl hyprsunset temperature)K"
      '';

      resetTemperature = pkgs.writeShellScript "hypr-reset-temperature" ''
        hyprctl hyprsunset reset temperature
        ${notify-send} --transient --urgency=low -t 2000 \
          -h 'string:x-canonical-private-synchronous:hyprsunset' "Hyprsunset" "Temperature reset to $(hyprctl hyprsunset temperature)K"
      '';

    in
    [
      (mkHyprExec "mod" "XF86MonBrightnessUp" "${modifyGamma} 5")
      (mkHyprExec "mod" "F8" "${modifyGamma} 5")
      (mkHyprExec "mod" "XF86MonBrightnessDown" "${modifyGamma} -5")
      (mkHyprExec "mod" "F7" "${modifyGamma} -5")
      (mkHyprExec "mod_shift" "XF86MonBrightnessUp" "${modifyTemperature} +200")
      (mkHyprExec "mod_shift" "F8" "${modifyTemperature} +200")
      (mkHyprExec "mod_shift" "XF86MonBrightnessDown" "${modifyTemperature} -200")
      (mkHyprExec "mod_shift" "F7" "${modifyTemperature} -200")

      # Reset with long press
      (mkHyprBind "mod" "XF86MonBrightnessUp" ''hl.dsp.exec_cmd("${resetGamma}"), { long_press = true }'')
      (mkHyprBind "mod" "F8" ''hl.dsp.exec_cmd("${resetGamma}"), { long_press = true }'')
      (mkHyprBind "mod" "XF86MonBrightnessDown" ''hl.dsp.exec_cmd("${resetGamma}"), { long_press = true }'')
      (mkHyprBind "mod" "F7" ''hl.dsp.exec_cmd("${resetGamma}"), { long_press = true }'')
      (mkHyprBind "mod_shift" "XF86MonBrightnessUp" ''hl.dsp.exec_cmd("${resetTemperature}"), { long_press = true }'')
      (mkHyprBind "mod_shift" "F8" ''hl.dsp.exec_cmd("${resetTemperature}"), { long_press = true }'')
      (mkHyprBind "mod_shift" "XF86MonBrightnessDown" ''hl.dsp.exec_cmd("${resetTemperature}"), { long_press = true }'')
      (mkHyprBind "mod_shift" "F7" ''hl.dsp.exec_cmd("${resetTemperature}"), { long_press = true }'')
    ];

  ns.desktop.programs.locker.postUnlockScript =
    "${lib.getExe' pkgs.hyprland "hyprctl"} hyprsunset reset gamma";
}
