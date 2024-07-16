{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.zathura;
  colors = config.colorScheme.palette;
in
lib.mkIf cfg.enable {
  programs.zathura = {
    enable = true;
    # recolor-reverse-video does not work with mupdf so disable it. Poppler is
    # slower though
    package = (pkgs.zathuraPkgs.override { useMupdf = false; }).zathuraWrapper;
    options = {
      default-bg = "#${colors.base00}";
      default-fg = "#${colors.base01}";
      statusbar-bg = "#${colors.base00}";
      statusbar-fg = "#${colors.base05}";
      inputbar-bg = "#${colors.base00}";
      inputbar-fg = "#${colors.base07}";
      notification-error-bg = "#${colors.base08}";
      notification-error-fg = "#${colors.base00}";
      notification-warning-bg = "#${colors.base08}";
      notification-warning-fg = "#${colors.base00}";
      highlight-color = "#${colors.base0A}4d";
      highlight-active-color = "#${colors.base0D}";
      completion-highlight-fg = "#${colors.base02}";
      completion-highlight-bg = "#${colors.base0C}";
      completion-bg = "#${colors.base02}";
      completion-fg = "#${colors.base0C}";
      notification-bg = "#${colors.base0B}";
      notification-fg = "#${colors.base00}";

      recolor = "false";
      recolor-lightcolor = "#${colors.base00}";
      recolor-darkcolor = "#${colors.base06}";
      recolor-reverse-video = "true";
      recolor-keephue = "true";

      font = "${config.modules.desktop.style.font.family} 10";
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = true;
      scroll-step = 50;
      render-loading = false;
      selection-clipboard = "clipboard";
      database = "null"; # don't store history
    };
    mappings = {
      # Map smooth scroll to j and k
      "j feedkeys" = "<C-Down>";
      "k feedkeys" = "<C-Up>";
      # Toggle dark theme
      "<C-l>" = "recolor";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "org.pwmt.zathura.desktop" ];
  };

  programs.zsh.shellAliases = {
    pdf = "zathura";
  };
}
