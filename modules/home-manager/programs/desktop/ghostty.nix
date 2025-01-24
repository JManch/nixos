{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf hiPrio;
  inherit (config.${ns}) desktop core;
  desktopId = "com.mitchellh.ghostty";

  mkTheme =
    theme:
    let
      inherit (core.colorScheme.${theme}) palette;
    in
    ''
      palette=0=#${palette.base02}
      palette=1=#${palette.base08}
      palette=2=#${palette.base0B}
      palette=3=#${palette.base0A}
      palette=4=#${palette.base0D}
      palette=5=#${palette.base0E}
      palette=6=#${palette.base0C}
      palette=7=#${palette.base07}
      background=${palette.base00}
      foreground=${palette.base05}
      cursor-color=${palette.base05}
      background-opacity=${if theme == "dark" then "0.7" else "1"}
    '';
in
{
  home.packages = [
    pkgs.ghostty
    # Modify the desktop entry to comply with the xdg-terminal-exec spec
    # https://gitlab.freedesktop.org/terminal-wg/specifications/-/merge_requests/3
    (hiPrio (
      pkgs.runCommand "ghostty-desktop-modify" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.ghostty}/share/applications/${desktopId}.desktop $out/share/applications/${desktopId}.desktop \
          --replace-fail "Type=Application" "Type=Application
        X-TerminalArgAppId=--class
        X-TerminalArgDir=--working-directory
        X-TerminalArgHold=--wait-after-command
        X-TerminalArgTitle=--title"
      ''
    ))
  ];

  xdg.configFile."ghostty/config".text = ''
    font-family=${desktop.style.font.family}
    window-decoration=false
    window-padding-x=5
    window-padding-y=5
    window-padding-balance=true
    window-padding-color=extend

    cursor-style=bar
    cursor-click-to-move
    mouse-hide-while-typing


    theme=light:base16-light,dark:base16-dark
    selection-invert-fg-bg
    minimum-contrast=1.1
  '';

  xdg.configFile."ghostty/themes/base16-dark".text = mkTheme "dark";
  xdg.configFile."ghostty/themes/base16-light".text = mkTheme "light";

  desktop.hyprland.binds = mkIf (desktop.terminal == desktopId) [
    "${desktop.hyprland.modKey}, Return, exec, app2unit ${desktopId}.desktop"
    "${desktop.hyprland.modKey}SHIFT, Return, workspace, emptym"
    "${desktop.hyprland.modKey}SHIFT, Return, exec, app2unit ${desktopId}.desktop"
  ];
}
