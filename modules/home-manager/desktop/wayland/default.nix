{ lib
, config
, ...
}:
with lib; {
  imports = [
    ./hyprland
    ./programs/anyrun.nix
    ./programs/swaylock.nix
    ./services/swayidle.nix
    ./services/waybar.nix
  ];
  options.desktop = {
    swaylock = {
      enable = mkEnableOption "Swaylock";
      lockScript = mkOption {
        type = types.str;
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
    anyrun.enable = mkEnableOption "Anyrun";
    waybar.enable = mkEnableOption "Waybar";
  };
}
