{ lib, ... }:
let
  inherit (lib) mkAliasOptionModule mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./. ++ [
    (mkAliasOptionModule [ "desktop" "hyprland" "binds" ] [ "wayland" "windowManager" "hyprland" "settings" "bind" ])
    (mkAliasOptionModule [ "desktop" "hyprland" "settings" ] [ "wayland" "windowManager" "hyprland" "settings" ])
  ];

  options.modules.desktop = {
    hyprland = {
      modKey = mkOption {
        type = types.str;
        description = "The modifier key to use for bindings";
        default = "SUPER";
      };
      # Used by gamemode config
      killActiveKey = mkOption {
        type = types.str;
        description = "The key to use for killing active window";
        default = "W";
      };
      tearing = mkEnableOption "enable tearing";
      blur = lib.overrideExisting (mkEnableOption "enable blur") { default = true; };
      animations = lib.overrideExisting (mkEnableOption "enable animations") { default = true; };
      logging = mkEnableOption "logging";
      directScanout = mkEnableOption "enable direct scanout";
    };
  };
}
