{ lib, config, ... }:
let
  inherit (lib) ns mkIf;
  cfg = config.${ns}.hardware.tablet;
in
mkIf cfg.enable {
  hardware.opentabletdriver.enable = true;

  systemd.user.services.opentabletdriver = {
    after = [ "graphical-session.target" ];
    serviceConfig.Slice = "background${lib.${ns}.sliceSuffix config}.slice";
    serviceConfig.SuccessExitStatus = 143;
  };

  persistenceHome.directories = [ ".config/OpenTabletDriver" ];
}
