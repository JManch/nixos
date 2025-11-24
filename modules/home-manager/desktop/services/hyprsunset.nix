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

  ns.desktop.hyprland.binds =
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
          -h 'string:x-canonical-private-synchronous:gamma' "Hyprsunset" "Gamma $new%"
      '';
    in
    [
      "${modKey}, XF86MonBrightnessUp, exec, ${modifyGamma} 5"
      "${modKey}, XF86MonBrightnessDown, exec, ${modifyGamma} -5"
    ];
}
