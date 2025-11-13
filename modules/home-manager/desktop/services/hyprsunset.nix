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
      time = 7:30
      identity = true
    }

    profile {
      time = 21:00
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
