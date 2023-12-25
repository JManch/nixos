{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (config.colorscheme) colors;
  inherit (lib) mkIf;
  cfg = config.desktop.wayland.swaylock;
in
  mkIf (cfg.enable) {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        line-uses-inside = true;
        grace = 3;
        clock = true;
        datestr = "%e %B %Y";

        font = config.font.family;
        font-size = 25;

        effect-blur = "10x3";
        fade-in = 0;

        disable-caps-lock-text = true;
        show-failed-attempts = true;

        indicator = true;
        indicator-caps-lock = true;
        indicator-y-position = builtins.floor (config.primaryMonitor.height * 0.5);
        indicator-radius = builtins.floor (config.primaryMonitor.width * 0.04);

        text-color = "#${colors.base07}";

        inside-color = "#${colors.base00}";
        ring-color = "#${colors.base00}";
        separator-color = "#${colors.base00}";

        inside-wrong-color = "#${colors.base08}";
        ring-wrong-color = "#${colors.base08}";
        bs-hl-color = "#${colors.base08}";
        text-wrong-color = "#${colors.base01}";

        key-hl-color = "#${colors.base0B}";
        ring-ver-color = "#${colors.base0B}";
        inside-ver-color = "#${colors.base0B}";
        text-ver-color = "#${colors.base01}";

        inside-clear-color = "#${colors.base0D}";
        ring-clear-color = "#${colors.base0D}";
        text-clear-color = "#${colors.base01}";

        text-caps-lock-color = "#${colors.base07}";
        inside-caps-lock-color = "#${colors.base00}";
        ring-caps-lock-color = "#${colors.base0E}";
      };
    };

    xdg.configFile."hypr/scripts/lock_screen.sh" = {
      text =
        /*
        bash
        */
        ''
          #!/bin/sh
          COMMAND="${config.wayland.windowManager.hyprland.package}/bin/hyprctl keyword decoration:screen_shader ${config.xdg.configHome}/hypr/shaders/"
          ''${COMMAND}blank.frag > /dev/null 2>&1
          ${config.programs.swaylock.package}/bin/swaylock -f
          ${pkgs.coreutils}/bin/sleep 0.05
          ''${COMMAND}monitor1_gamma.frag > /dev/null 2>&1
        '';
      executable = true;
    };
  }
