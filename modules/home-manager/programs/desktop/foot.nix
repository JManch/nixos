{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf hiPrio;
  inherit (config.${ns}) desktop;
in
{
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "${config.${ns}.desktop.style.font.family}:size=12";
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

  home.packages = [
    # Modify the desktop entry to comply with the xdg-terminal-exec spec
    # https://gitlab.freedesktop.org/terminal-wg/specifications/-/merge_requests/3
    (hiPrio (
      pkgs.runCommand "foot-desktop-modify" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.foot}/share/applications/foot.desktop $out/share/applications/foot.desktop \
          --replace-fail "Type=Application" "Type=Application
        X-TerminalArgAppId=--app-id
        X-TerminalArgDir=--working-directory
        X-TerminalArgHold=--hold
        X-TerminalArgTitle=--title"
      ''
    ))
  ];

  ns.desktop.hyprland.binds = mkIf (desktop.terminal == "foot") [
    "${desktop.hyprland.modKey}, Return, exec, app2unit foot.desktop"
    "${desktop.hyprland.modKey}SHIFT, Return, workspace, emptym"
    "${desktop.hyprland.modKey}SHIFT, Return, exec, app2unit foot.desktop"
  ];
}
