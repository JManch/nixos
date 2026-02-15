{
  lib,
  pkgs,
  config,
}:
let
  inherit (config.colorScheme) palette;
in
{
  programs.zathura = {
    enable = true;
    # recolor-reverse-video does not work with mupdf so disable it. Poppler is
    # slower though
    package = (pkgs.zathuraPkgs.override { useMupdf = false; }).zathuraWrapper;
    options = {
      default-bg = "#${palette.base00}";
      default-fg = "#${palette.base01}";
      statusbar-bg = "#${palette.base00}";
      statusbar-fg = "#${palette.base05}";
      inputbar-bg = "#${palette.base00}";
      inputbar-fg = "#${palette.base07}";
      notification-error-bg = "#${palette.base08}";
      notification-error-fg = "#${palette.base00}";
      notification-warning-bg = "#${palette.base08}";
      notification-warning-fg = "#${palette.base00}";
      highlight-color = "#${palette.base0A}4d";
      highlight-active-color = "#${palette.base0D}";
      completion-highlight-fg = "#${palette.base02}";
      completion-highlight-bg = "#${palette.base0C}";
      completion-bg = "#${palette.base02}";
      completion-fg = "#${palette.base0C}";
      notification-bg = "#${palette.base0B}";
      notification-fg = "#${palette.base00}";

      recolor = "false";
      recolor-lightcolor = "#${palette.base00}";
      recolor-darkcolor = "#${palette.base06}";
      recolor-reverse-video = "true";
      recolor-keephue = "true";

      font = "${config.${lib.ns}.desktop.style.font.family} 10";
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = true;
      scroll-step = 50;
      render-loading = false;
      selection-clipboard = "clipboard";
      database = "null"; # don't store history
    };
    mappings = {
      "j" = "navigate next";
      "k" = "navigate previous";

      # Map smooth scroll to J and K
      "J feedkeys" = "<C-Down>";
      "K feedkeys" = "<C-Up>";

      # Toggle dark theme
      "<C-l>" = "recolor";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "org.pwmt.zathura.desktop" ];
  };
}
