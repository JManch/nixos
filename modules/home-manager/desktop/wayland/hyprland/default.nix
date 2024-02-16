{ lib, config, ... }:
let
  inherit (lib) mkAliasOptionModule mkEnableOption mkOption types;
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  shaderDir = "${config.xdg.configHome}/hypr/shaders";
in
{
  imports = lib.utils.scanPaths ./. ++ [
    (mkAliasOptionModule [ "desktop" "hyprland" "binds" ] [ "wayland" "windowManager" "hyprland" "settings" "bind" ])
    (mkAliasOptionModule [ "desktop" "hyprland" "settings" ] [ "wayland" "windowManager" "hyprland" "settings" ])
  ];

  options.modules.desktop.hyprland = {
    modKey = mkOption {
      type = types.str;
      default = "SUPER";
      description = "The modifier key to use for bindings";
    };
    secondaryModKey = mkOption {
      type = types.str;
      default = "ALT";
      description = ''
        Modifier key used for virtual machines or nested instances of
        hyprland to avoid clashes.
      '';
    };
    # Used by gamemode config
    killActiveKey = mkOption {
      type = types.str;
      description = "The key to use for killing active window";
      default = "W";
    };
    enableShaders = mkOption {
      type = types.str;
      default = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/monitorGamma.frag";
      description = "Command to enable Hyprland screen shaders";
    };
    disableShaders = mkOption {
      type = types.str;
      default = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/blank.frag";
      description = "Command to disable Hyprland screen shaders";
    };
    tearing = mkEnableOption "enable tearing";
    blur = lib.overrideExisting (mkEnableOption "enable blur") { default = true; };
    animations = lib.overrideExisting (mkEnableOption "enable animations") { default = true; };
    logging = mkEnableOption "logging";
    directScanout = mkEnableOption "enable direct scanout";
  };
}
