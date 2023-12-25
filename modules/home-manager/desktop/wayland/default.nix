{
  lib,
  config,
  ...
}:
with lib; {
  options.desktop.wayland = {
    swaylock = {
      enable = mkEnableOption "Swaylock";
      lockScript = mkOption {
        type = types.string;
        description = "Script to run to lock the screen.";
        default = ''
          ${config.swaylock.package}/bin/swaylock -f
        '';
      };
    };
    swayidle = {
      enable = mkEnableOption "Swayidle";
      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Lock screen after this many idle seconds.";
      };
      screenOffTime = mkOption {
        type = types.int;
        default = 5 * 60;
        description = "Turn off screen after this many idle seconds.";
      };
      lockedScreenOffTime = mkOption {
        type = types.int;
        default = 2 * 60;
        description = "Turn off screen after this many idle seconds locked.";
      };
    };
  };
}
