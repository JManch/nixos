{
  lib,
  cfg,
  config,
  hostname,
}:
let
  inherit (config.${lib.ns}) desktop;
  colors = config.colorScheme.palette;
in
{
  programs.waybar.style =
    let
      inherit (desktop.style)
        gapSize
        cornerRadius
        borderWidth
        font
        ;
      halfCornerRadius = toString (cornerRadius / 2);
      borderWidthStr = toString borderWidth;
    in
    # css
    ''
      @define-color background #${colors.base00};
      @define-color border #${colors.base04};
      @define-color text-dark #${colors.base00};
      @define-color text-light #${colors.base07};
      @define-color green #${colors.base0B};
      @define-color blue #${colors.base0D};
      @define-color red #${colors.base08};
      @define-color purple #${colors.base0E};
      @define-color orange #${colors.base0F};
      @define-color transparent rgba(0,0,0,0);

      * {
          font-family: '${font.family}';
          font-size: 15px;
          font-weight: 600;
          text-shadow: none;
          min-height: 0px;
          border: none;
      }

      tooltip {
          background: @background;
          border-radius: ${halfCornerRadius}px;
          border: ${borderWidthStr}px solid @blue;
      }

      tooltip label {
          color: @text-light;
          margin: 0px;
          padding: 0px;
      }

      window#waybar {
          background: @background;
          color: @text-light;
          border-radius: ${
            if cfg.float then
              toString cornerRadius
            else
              (
                if hostname == "framework" then
                  if cfg.bottom then
                    "7px 7px 0px 0"
                  else
                    "0px 0px ${toString cornerRadius}px ${toString cornerRadius}"
                else
                  "0"
              )
          }px;
      }

      #workspaces {
          margin: 5px 0px 5px ${if cfg.float then "5" else toString gapSize}px;
          padding: 0px;
          border-radius: ${halfCornerRadius}px;
          background: @blue;
      }

      button {
          border-color: @transparent;
          background: @transparent;
      }

      #workspaces button {
          margin: 0px;
          padding: 0px;
      }

      #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
      }

      #workspaces button label {
          border: ${borderWidthStr}px solid @transparent;
          border-radius: 5px;
          padding: 0px 6px;
          margin: 4px 5px;
          color: @text-dark;
          font-weight: 500;
      }

      #workspaces button.visible label {
          border: ${borderWidthStr}px solid @background;
          background: @transparent;
          color: @text-dark;
      }

      #workspaces button.active label {
          border: ${borderWidthStr}px solid @background;
          background: @background;
          color: @text-light;
          font-weight: 900;
      }

      #custom-poweroff {
          padding-right: 4px;
          color: @red;
      }

      #custom-hostname, #power-profiles-daemon {
          margin: 5px ${if cfg.float then "5" else toString gapSize}px 5px 0px;
          padding: 0px 7px;
          border-radius: ${halfCornerRadius}px;
          background: @blue;
          color: @text-dark;
      }

      #custom-vpn {
          margin-right: 3px;
      }
    '';
}
