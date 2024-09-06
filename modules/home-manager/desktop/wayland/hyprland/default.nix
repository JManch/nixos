{
  ns,
  lib,
  config,
  ...
}@args:
let
  inherit (lib)
    mkAliasOptionModule
    mkEnableOption
    mkOption
    types
    getExe'
    escapeShellArg
    ;
  inherit (lib.${ns}) scanPaths flakePkgs;
  cfg = config.${ns}.desktop.hyprland;
  hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
in
{
  imports = scanPaths ./. ++ [
    (mkAliasOptionModule
      [
        "desktop"
        "hyprland"
        "binds"
      ]
      [
        "wayland"
        "windowManager"
        "hyprland"
        "settings"
        "bind"
      ]
    )

    (mkAliasOptionModule
      [
        "desktop"
        "hyprland"
        "settings"
      ]
      [
        "wayland"
        "windowManager"
        "hyprland"
        "settings"
      ]
    )
  ];

  options.${ns}.desktop.hyprland = {
    logging = mkEnableOption "logging";
    tearing = mkEnableOption "enable tearing";
    directScanout = mkEnableOption ''
      enable direct scanout. Direct scanout reduces input lag for fullscreen
      applications however might cause graphical glitches.
    '';

    hyprcursor = {
      name = mkOption {
        type = types.str;
        description = "Hyprcursor name";
        default = "Hypr-Bibata-Modern-Classic";
      };

      package = mkOption {
        type = types.nullOr types.package;
        default = (flakePkgs args "nix-resources").bibata-hyprcursors;
        description = ''
          A Hyprcursor compatible cursor package. Set to null to disable Hyprcursor.
        '';
      };
    };

    blur = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable blur";
    };

    animations = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable blur";
    };

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

    killActiveKey = mkOption {
      type = types.str;
      default = "W";
      description = "Key to use for killing the active window";
    };

    shaderDir = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.xdg.configHome}/hypr/shaders";
    };

    enableShaders = mkOption {
      type = types.str;
      readOnly = true;
      default = "${escapeShellArg hyprctl} keyword decoration:screen_shader '${cfg.shaderDir}/monitorGamma.frag'";
      description = "Command to enable Hyprland screen shaders";
    };

    disableShaders = mkOption {
      type = types.str;
      readOnly = true;
      default = "${escapeShellArg hyprctl} keyword decoration:screen_shader '${cfg.shaderDir}/blank.frag'";
      description = "Command to disable Hyprland screen shaders";
    };
  };
}
