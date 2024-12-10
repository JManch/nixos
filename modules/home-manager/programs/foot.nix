{ lib, config, ... }:
let
  inherit (config.${lib.ns}.desktop) style;
  cfg = config.${lib.ns}.programs.foot;
in
lib.mkIf cfg.enable {
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "${style.font.family}:size=12";
        pad = "5x5";
      };

      cursor = {
        style = "beam";
        unfocused-style = "hollow";
        blink = "yes";
        beam-thickness = 1.5;
      };

      mouse = {
        hide-when-typing = true;
      };

      colors =
        let
          colors = config.colorScheme.palette;
        in
        {
          alpha = 0.7;
          background = colors.base00;
          foreground = colors.base05;
          regular0 = colors.base02;
          regular1 = colors.base08;
          regular2 = colors.base0B;
          regular3 = colors.base0A;
          regular4 = colors.base0D;
          regular5 = colors.base0E;
          regular6 = colors.base0C;
          regular7 = colors.base07;
        };
    };
  };
}
