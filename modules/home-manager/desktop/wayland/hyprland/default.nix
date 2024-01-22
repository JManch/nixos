{ lib, ... }:
with lib; {
  imports = [
    ./hyprland.nix
    ./shaders.nix
    ./binds.nix
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
      killActiveKey = mkOption {
        type = types.str;
        description = "The key to use for killing active window. Has to be set here because gamemode config uses it.";
        default = "W";
      };
      tearing = mkEnableOption "allow tearing";
      blur = lib.overrideExisting (mkEnableOption "enable blur") { default = true; };
      logging = mkEnableOption "logging";
    };
  };
}
