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
      tearing = mkEnableOption "allow tearing";
      blur = lib.overrideExisting (mkEnableOption "enable blur") { default = true; };
      logging = mkEnableOption "logging";
    };
  };
}
