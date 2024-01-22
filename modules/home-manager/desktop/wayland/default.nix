{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
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
        default = 4 * 60;
        description = "Turn off screen after this many idle seconds";
      };
    };
    anyrun.enable = mkEnableOption "Anyrun";
    waybar.enable = mkEnableOption "Waybar";
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
