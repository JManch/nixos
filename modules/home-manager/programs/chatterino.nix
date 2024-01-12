{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.chatterino;
  desktopCfg = config.modules.desktop;
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  chatterinoRatio = 1.6;
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    chatterino2
  ];

  impermanence.directories = [
    ".local/share/chatterino"
  ];

  desktop.hyprland.settings = lib.mkIf (desktopCfg.windowManager == "hyprland") {
    workspace = [
      "name:TWITCH,monitor:${(lib.fetchers.getMonitorByNumber nixosConfig 2).name},gapsin:0,gapsout:0,rounding:false,border:false}"
    ];
    bind = [
      "${config.modules.desktop.hyprland.modKey}, T, workspace, name:TWITCH"
      "${config.modules.desktop.hyprland.modKey}SHIFT, T, exec, ${hyprctl} dispatch splitratio exact ${builtins.toString chatterinoRatio}"
    ];
    windowrulev2 = [
      "workspace name:TWITCH,class:^(com\.chatterino\.)$"
      "workspace name:TWITCH,class:mpv,title:^(twitch\.tv.*)$"
    ];
  };
}
