{
  ns,
  lib,
  config,
  ...
}:
let
  cfg = config.${ns}.hardware.tablet;
in
lib.mkIf cfg.enable {
  hardware.opentabletdriver.enable = true;

  persistenceHome.directories = [
    ".config/OpenTabletDriver"
  ];
}
