{ lib
, pkgs
, inputs
, config
, hostname
, osConfig
, ...
}:
let
  inherit (lib) mkIf utils fetchers toUpper;
  cfg = config.modules.desktop.programs.hyprlock;
  colors = config.colorscheme.palette;

  isWayland = fetchers.isWayland config;
  primaryMonitor = fetchers.primaryMonitor osConfig;
  wallpapers = (utils.flakePkgs { inherit pkgs inputs; } "nix-resources").wallpapers;
in
{
  imports = [
    inputs.hyprlock.homeManagerModules.default
  ];

  config = mkIf (cfg.enable && isWayland) {
    programs.hyprlock = {
      enable = true;

      general = {
        disable_loading_bar = false;
        hide_cursor = true;
      };

      backgrounds = [{
        path = wallpapers.rx7.outPath;
        color = "0xff${colors.base00}";
      }];

      input-fields = [{
        monitor = primaryMonitor.name;
        size.width = 300;
        size.height = 40;
        outline_thickness = 3;
        outer_color = "0xff${colors.base00}";
        inner_color = "0xff${colors.base00}";
        font_color = "0xff${colors.base07}";
        fade_on_empty = true;
        placeholder_text = "";
        hide_input = false;
        position = { x = 0; y = -30; };
        halign = "center";
        valign = "center";
      }];

      labels = [{
        monitor = primaryMonitor.name;
        text = toUpper hostname;
        position = { x = 0; y = 30; };
        font_family = config.modules.desktop.style.font.family;
        font_size = 40;
        color = "0xff${colors.base07}";
      }];
    };
  };
}
