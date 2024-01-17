{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.cava;
in
lib.mkIf (cfg.enable && nixosConfig.modules.system.audio.enable) {
  programs.cava = {
    enable = true;
    settings = {
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
        alacritty_sync = 1;
      };
      color = {
        gradient = 1;
        gradient_count = 5;
        gradient_color_1 = "'#${config.colorscheme.colors.base0C}'";
        gradient_color_2 = "'#${config.colorscheme.colors.base0B}'";
        gradient_color_3 = "'#${config.colorscheme.colors.base0A}'";
        gradient_color_4 = "'#${config.colorscheme.colors.base09}'";
        gradient_color_5 = "'#${config.colorscheme.colors.base08}'";
      };
      smoothing = {
        monstercat = 0;
        waves = 0;
      };
    };
  };

  xdg.desktopEntries."cava" = {
    name = "Cava";
    genericName = "Audio Visualizer";
    exec = "${pkgs.alacritty}/bin/alacritty --title Cava -e ${config.programs.cava.package}/bin/cava";
    terminal = false;
    type = "Application";
    categories = [ "Audio" ];
  };
}
