{ lib, ... }:
with lib; {
  imports = [
    ./hyprland.nix
    ./shaders.nix
    ./binds.nix
    (mkAliasOptionModule [ "desktop" "hyprland" "binds" ] [ "wayland" "windowManager" "hyprland" "settings" "bind" ])
  ];
  options.modules.desktop = {
    hyprland = {
      modKey = mkOption {
        type = types.str;
        description = "The modifier key to use for bindings";
        default = "SUPER";
      };
    };
  };
}
