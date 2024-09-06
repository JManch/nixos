{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.zed;
  jsonFormat = pkgs.formats.json { };
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.zed-editor ];

  xdg.configFile."zed/settings.json".source = jsonFormat.generate "settings.json" {
    auto_update = false;
    telemetry = {
      diagnostics = false;
      metrics = false;
    };
    theme = {
      # System theme switching doesn't seem to work on Linux
      mode = "dark";
      dark = "Ayu Mirage";
      light = "Ayu Light";
    };
    current_line_highlight = "none";
    vim_mode = true;
    scrollbar.show = "never";
    ui_font_size = 18;
    buffer_font_family = "BerkeleyMono Nerd Font";
    buffer_font_size = 18;
    inlay_hints.enabled = true;
  };

  persistence.directories = [ ".local/share/zed" ];
}
