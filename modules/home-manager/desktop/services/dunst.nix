{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    getExe'
    mkForce
    mkOption
    types
    ;
  inherit (config.${ns}) desktop;
  inherit (config.${ns}.core.color-scheme) light;
  inherit (osConfig.${ns}.core) device;
  colors = config.colorScheme.palette;
  systemctl = getExe' pkgs.systemd "systemctl";
  dunstctl = getExe' config.services.dunst.package "dunstctl";
in
{
  opts.monitorNumber = mkOption {
    type = types.int;
    default = 1;
    description = "The monitor number to display notifications on";
  };

  services.dunst = {
    enable = true;

    package =
      assert (
        lib.assertMsg (
          pkgs.dunst.version == "1.13.0"
        ) "Hopefully https://github.com/dunst-project/dunst/issues/1471 is fixed by now"
      );
      pkgs.dunst.overrideAttrs {
        version = "0-unstable-2025-11-13";
        # Fixes an issue with icons not updating when performing stack tag
        # replacements
        src = pkgs.fetchFromGitHub {
          owner = "fedang";
          repo = "dunst";
          rev = "ca42a0a14e672c7ee079731124f2965fa1bb34d3";
          hash = "sha256-zO+ZDFpadf6Mn4cUKewZGLrOj5LOME+R1gb3+jVGQz0=";
        };
      };

    settings = {
      global =
        let
          inherit (desktop.style)
            font
            cornerRadius
            gapSize
            borderWidth
            ;
        in
        {
          monitor = toString cfg.monitorNumber;
          # follow mouse on laptops for external monitor usage
          follow = if (device.type == "laptop") then "mouse" else "none";
          # I can't get newline matching to work with this enabled. If changing
          # update regex in poweralertd module.
          enable_posix_regex = false;
          font = "${font.family} 13";
          icon_theme = config.gtk.iconTheme.name;
          show_indicators = true;
          format = "<b>%s</b>\\n<span font='11'>%b</span>";
          layer = "overlay";

          corner_radius = cornerRadius;
          width = builtins.floor (device.primaryMonitor.width * 0.14);
          height = "(0, ${toString (builtins.floor (device.primaryMonitor.height * 0.25))})";
          offset =
            let
              offset = (gapSize * 2) + borderWidth;
            in
            "(${toString offset}, ${toString offset})";
          gap_size = gapSize;
          frame_width = borderWidth;
          transparency = 100;

          mouse_left_click = "do_action";
          mouse_middle_click = "close_all";
          mouse_right_click = "close_current";
          sort = true;
          stack_duplicates = true;
          min_icon_size = 128;
          max_icon_size = 128;
          markup = "full";
        };

      fullscreen_delay_everything = {
        fullscreen = "show";
      };

      urgency_critical = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base08}";
      };

      urgency_normal = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base0E}";
      };

      urgency_low = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base0D}";
      };
    };
  };

  systemd.user.services.dunst = {
    Unit.After = mkForce [ "graphical-session.target" ];
    Unit.Requisite = [ "graphical-session.target" ];
    Service.Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
  };

  ns.desktop = {
    darkman.switchApps.dunst = {
      paths = [ ".config/dunst/dunstrc" ];
      reloadScript = "${systemctl} restart --user dunst";

      colorOverrides = {
        base00 = {
          dark = "${colors.base00}b3";
          light = "${light.palette.base00}";
        };
      };
    };

    programs.locker = {
      preLockScript = "${dunstctl} set-paused true";
      postUnlockScript = "${dunstctl} set-paused false";
    };

    hyprland.settings.layerrule = [
      "blur, notifications"
      "xray 0, notifications"
      "animation slide, notifications"
    ];
  };
}
