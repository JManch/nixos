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
      color = let colors = config.colorscheme.palette; in {
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
  };

  xdg.desktopEntries."cava" = {
    name = "Cava";
    genericName = "Audio Visualizer";
    exec = "${config.programs.alacritty.package}/bin/alacritty --title Cava -e ${config.programs.cava.package}/bin/cava";
    terminal = false;
    type = "Application";
    categories = [ "Audio" ];
  };
}
