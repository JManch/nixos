{ lib, config, osConfig', ... }:
let
  inherit (lib) mkIf getExe;
  cfg = config.modules.programs.cava;
in
mkIf (cfg.enable && (osConfig'.modules.system.audio.enable or true)) {
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

      color = let colors = config.colorScheme.palette; in {
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

  xdg.desktopEntries.cava =
    let
      cava = getExe config.programs.cava.package;
      terminal = config.modules.desktop.terminal.exePath;
    in
    mkIf config.modules.desktop.enable {
      name = "Cava";
      genericName = "Audio Visualizer";
      exec = "${terminal} --title Cava -e ${cava}";
      terminal = false;
      type = "Application";
      categories = [ "Audio" ];
    };
}
