{
  lib,
  args,
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
}
