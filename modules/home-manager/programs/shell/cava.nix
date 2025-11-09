{
  lib,
  pkgs,
  config,
}:
{
  conditions = [ "osConfig.system.audio" ];

  home.packages = [ pkgs.cava ];

  xdg.configFile."cava/config".text = lib.generators.toINI { } {
    general = {
      framerate = 60;
      autosens = 1;
      bars = 0;
      bar_width = 2;
      bar_spacing = 1;
    };

    input = {
      method = "pulse";
      source = "auto";
    };

    output = {
      channels = "mono";
      synchronized_sync = 1;
    };

    color =
      let
        colors = config.colorScheme.palette;
      in
      {
        gradient = 1;
        gradient_count = 5;
        gradient_color_1 = "'#${colors.base0C}'";
        gradient_color_2 = "'#${colors.base0B}'";
        gradient_color_3 = "'#${colors.base0A}'";
        gradient_color_4 = "'#${colors.base09}'";
        gradient_color_5 = "'#${colors.base08}'";
      };

    smoothing = {
      monstercat = 0;
      waves = 0;
    };
  };

  xdg.desktopEntries.cava = lib.mkIf config.${lib.ns}.desktop.enable {
    name = "Cava";
    genericName = "Audio Visualizer";
    exec = ''xdg-terminal-exec --title=Cava --app-id=cava -e zsh "-c" "alacritty msg config font.size=9 || true; cava"'';
    terminal = false;
    type = "Application";
    icon = "org.pulseaudio.pavucontrol";
    categories = [ "Audio" ];
  };

  ns.desktop.hyprland.settings.windowrule = [
    "float, class:^(cava)$"
    "size 50% 20%, class:^(cava)$"
    "center, class:^(cava)$"
  ];
}
