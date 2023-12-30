{ lib, ... }:
with lib; {
  imports = [
    ./hyprland.nix
    ./shaders.nix
    ./binds.nix
    (mkAliasOptionModule [ "desktop" "hyprland" "binds" ] [ "wayland" "windowManager" "hyprland" "settings" "bind" ])
  ];
  options.modules.desktop = {
    compositor = mkOption {
      type = with types; nullOr (enum [ "hyprland" ]);
    };
    hyprland = {
      modKey = mkOption {
        type = types.str;
        description = "The modifier key to use for bindings";
        default = "SUPER";
      };
    };
  };
}
