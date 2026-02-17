{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    ;
  inherit (osConfig.${ns}.core.device) primaryMonitor;
  inherit (osConfig.programs) uwsm;
  desktopCfg = config.${ns}.desktop;
  colors = config.colorScheme.palette;
in
{
  programs.fuzzel = {
    enable = true;
    package = lib.${ns}.addPatches pkgs.fuzzel [
      # Fixes icons for apps that only package an icon in share/pixmaps
      # https://codeberg.org/dnkl/fuzzel/issues/692
      ../../../../patches/fuzzel-fix-pixmap-icons.patch
    ];

    settings = {
      main = {
        launch-prefix = mkIf uwsm.enable "app2unit -t service --";
        terminal = "xdg-terminal-exec";

        font = "${desktopCfg.style.font.family}:size=${
          toString (builtins.ceil (primaryMonitor.height * 0.0125))
        }";
        lines = 5;
        width = 30;
        horizontal-pad = 20;
        vertical-pad = 12;
        inner-pad = 5;
        anchor = "bottom";
        y-margin = builtins.floor ((primaryMonitor.height / primaryMonitor.scale) * 0.43);

        tabs = 4;
        prompt = "\"\"";
        icons-enabled = true;
        icon-theme = config.gtk.iconTheme.name;
        fields = "name,generic,keywords";
        image-size-ratio = 1; # disable the large icon images
      };

      colors = {
        background = "${colors.base00}ff";
        input = "${colors.base07}ff";
        text = "${colors.base05}ff";
        match = "${colors.base05}ff";
        selection = "${colors.base00}ff";
        selection-text = "${colors.base07}ff";
        selection-match = "${colors.base07}ff";
        border = "${colors.base0D}ff";
      };

      border = {
        width = 2;
        radius = desktopCfg.style.cornerRadius;
      };

      key-bindings = {
        delete-line-forward = "none"; # defaults to Control+k
        delete-line-backward = "none";
        prev = "Up Control+p Control+k";
        next = "Down Control+n Control+j";
      };
    };
  };

  home.packages = mkIf uwsm.enable [
    (pkgs.runCommand "uuctl-desktop-customise" { } ''
      mkdir -p $out/share/applications
      substitute ${osConfig.programs.uwsm.package}/share/applications/uuctl.desktop $out/share/applications/uuctl.desktop \
        --replace-fail "Name=uuctl" "Name=Unit Manager" \
        --replace-fail "Exec=uuctl" "Exec=uuctl fuzzel --dmenu -R --log-no-syslog --log-level=warning --font=\"${desktopCfg.style.font.family}:size=16\" --width=60 --lines=10 --y-margin=${
          toString (builtins.floor (primaryMonitor.height * 0.36))
        } -p"
    '')
  ];

  ns.desktop.darkman.switchApps.fuzzel =
    let
      inherit (config.${ns}.core.color-scheme) dark light;
    in
    {
      paths = [ ".config/fuzzel/fuzzel.ini" ];
      colorOverrides = {
        base05 = {
          dark = dark.palette.base05;
          light = light.palette.base04;
        };
      };
    };

  ns.desktop.hyprland.settings =
    let
      inherit (desktopCfg.hyprland) modKey;
      hyprlandWindowSwitcher = pkgs.writeShellApplication {
        name = "hyprland-fuzzel-window-switcher";
        runtimeInputs = with pkgs; [
          jaq
          fuzzel
          hyprland
          gnused
        ];
        text = ''
          clients=$(hyprctl -j clients)
          selections=$(jaq -r 'map(select((.mapped == true) and (.workspace.name | startswith("special:") | not))) | sort_by(.focusHistoryID) | .[] | "\(.address)\t\(.workspace.name)\t\(.title)\\x0icon\\x1f\(.class)"' <<< "$clients" \
            | column -t -s $'\t' -o $'\t' \
            | sed 1d)

          selection_index=$(echo -e "$selections" \
            | cut -d $'\t' -f 2- \
            | fuzzel --dmenu --index --font "${desktopCfg.style.font.family}:size=${
              toString (builtins.ceil (primaryMonitor.height * 0.0083))
            }" --anchor center --width 80 --lines 18)

          if [[ -z $selection_index ]]; then exit 0; fi

          selection=$(sed -n "$((selection_index + 1))p" <<< "$selections")
          IFS=$'\t' read -r address _ _ <<< "$selection"
          hyprctl dispatch focuswindow "address:$address"
        '';
      };
    in
    {
      bindr = [ "${modKey}, ${modKey}_L, exec, ${getExe' pkgs.procps "pkill"} fuzzel || fuzzel" ];
      bind = [
        "${modKey}, Space, exec, ${getExe' pkgs.procps "pkill"} fuzzel || ${getExe hyprlandWindowSwitcher}"
      ];
      layerrule = [ "match:namespace launcher, animation slide" ];
    };
}
