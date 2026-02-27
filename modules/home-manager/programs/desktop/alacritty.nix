{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    singleton
    hiPrio
    ;
  inherit (config.${ns}) desktop;
  inherit (config.${ns}.programs.shell) zellij;
  colors = config.colorScheme.palette;
in
{
  programs.alacritty = {
    enable = true;

    settings = {
      mouse.hide_when_typing = true;

      scrolling.history = 10000;

      window = {
        padding = {
          x = 6;
          y = 6;
        };
        dynamic_padding = true;
        decorations = "none";
        opacity = 0.7;
        dynamic_title = true;
      };

      font = {
        size = 12;
        normal = {
          family = desktop.style.font.family;
          style = "Regular";
        };
      };

      colors = {
        primary = {
          background = "#${colors.base00}";
          foreground = "#${colors.base05}";
          bright_foreground = "#${colors.base06}";
        };

        normal = {
          black = "#${colors.base02}";
          red = "#${colors.base08}";
          green = "#${colors.base0B}";
          yellow = "#${colors.base0A}";
          blue = "#${colors.base0D}";
          magenta = "#${colors.base0E}";
          cyan = "#${colors.base0C}";
          white = "#${colors.base07}";
        };
      };

      cursor = {
        blink_interval = 500;
        style = {
          shape = "Beam";
          blinking = "On";
        };
      };

      keyboard.bindings = mkIf (!zellij.enable) [
        {
          key = "K";
          mods = "Alt";
          action = "ScrollLineUp";
        }
        {
          key = "J";
          mods = "Alt";
          action = "ScrollLineDown";
        }
        {
          key = "D";
          mods = "Alt";
          action = "ScrollHalfPageDown";
        }
        {
          key = "U";
          mods = "Alt";
          action = "ScrollHalfPageUp";
        }
      ];
    };
  };

  home.packages = [
    # Modify the desktop entry to comply with the xdg-terminal-exec spec
    # https://gitlab.freedesktop.org/terminal-wg/specifications/-/merge_requests/3
    (hiPrio (
      pkgs.runCommand "alacritty-desktop-modify" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.alacritty}/share/applications/Alacritty.desktop $out/share/applications/Alacritty.desktop \
          --replace-fail "Type=Application" "Type=Application
        X-TerminalArgAppId=--class
        X-TerminalArgDir=--working-directory
        X-TerminalArgHold=--hold
        X-TerminalArgTitle=--title"
      ''
    ))
  ];

  ns.desktop = {
    darkman.switchApps.alacritty = {
      paths = [ ".config/alacritty/alacritty.toml" ];
      extraReplacements = singleton {
        dark = "opacity = 0.7";
        light = "opacity = 1";
      };
    };

    hyprland = {
      settings.windowrule = [ "match:class Alacritty, scroll_touchpad 0.6" ];

      binds = mkIf (desktop.terminal == "Alacritty") [
        "${desktop.hyprland.modKey}, Return, exec, app2unit -t service Alacritty.desktop"
        "${desktop.hyprland.modKey}SHIFT, Return, workspace, emptym"
        "${desktop.hyprland.modKey}SHIFT, Return, exec, app2unit -t service Alacritty.desktop"
      ];
    };
  };
}
