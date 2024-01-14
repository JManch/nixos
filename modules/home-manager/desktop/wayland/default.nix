{ lib
, pkgs
, config
, nixosConfig
, ...
}:
with lib; {
  imports = [
    ./hyprland
    ./programs/anyrun.nix
    ./programs/swaylock.nix
    ./services/waybar
    ./services/swww.nix
    ./services/swayidle.nix
  ];
  options.modules.desktop = {
    swaylock = {
      enable = mkEnableOption "Swaylock";
      lockScript = mkOption {
        type = types.str;
        description = "Path to script that locks the screen";
        default = (pkgs.writeShellScript "swaylock-lock" ''
          ${config.swaylock.package}/bin/swaylock -f
        '').outPath;
      };
    };
    swayidle = {
      enable = mkEnableOption "Swayidle";
      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Lock screen after this many idle seconds";
      };
      screenOffTime = mkOption {
        type = types.int;
        default = 5 * 60;
        description = "Turn off screen after this many idle seconds";
      };
      lockedScreenOffTime = mkOption {
        type = types.int;
        default = 2 * 60;
        description = "Turn off screen after this many idle seconds locked";
      };
    };
    anyrun.enable = mkEnableOption "Anyrun";
    waybar.enable = mkEnableOption "Waybar";
    swww.enable = mkEnableOption "Swww";
  };

  config =
    let
      isWayland = lib.fetchers.isWayland config;
      osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
    in
    lib.mkIf (osDesktopEnabled && isWayland) {
      home.packages = with pkgs; [
        wl-clipboard
      ];
    };
}
