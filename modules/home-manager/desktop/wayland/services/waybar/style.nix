{ lib
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.desktop.waybar;
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.colors;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
  isWayland = lib.fetchers.isWayland config;
in
lib.mkIf (osDesktopEnabled && isWayland && cfg.enable)
{
  programs.waybar.style =
    let
      halfCornerRadius = builtins.toString (desktopCfg.style.cornerRadius / 2);
      borderWidth = builtins.toString desktopCfg.style.borderWidth;
      gapSize = desktopCfg.style.gapSize;
    in
      /* css */ ''
      @define-color background #${colors.base00};
      @define-color border #${colors.base05};
      @define-color text-dark #${colors.base00};
      @define-color text-light #${colors.base07};
      @define-color green #${colors.base0B};
      @define-color blue #${colors.base0D};
      @define-color red #${colors.base08};
      @define-color purple #${colors.base0E};
      @define-color orange #${colors.base0F};
      @define-color transparent rgba(0,0,0,0);

      * {
          font-family: '${desktopCfg.style.font.family}';
          font-size: 16px;
          font-weight: 600;
          min-height: 0px;
      }

      tooltip {
          background: @background;
          color: @text-light;
          border-radius: ${halfCornerRadius}px;
          border: ${borderWidth}px solid @background;
      }

      window#waybar {
          background: @background;
          color: @text-light;
          border-radius: 0px;
          border: ${borderWidth}px solid @background;
      }

      window#waybar.fullscreen {
          border-bottom: ${borderWidth}px solid @blue;
      }

      #workspaces {
          margin: 5px 0px 5px ${builtins.toString (gapSize + 2)}px;
          padding: 0px 0px;
          border-radius: ${halfCornerRadius}px;
          background: @blue;
      }

      button {
        border-color: @transparent;
        background: @transparent;
      }

      #workspaces button {
          padding: 5px;
      }

      #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
      }

      #workspaces button label {
          border-radius: ${halfCornerRadius}px;
          border: ${borderWidth}px solid @transparent;

          padding: 0px 0.4em;

          color: @text-dark;
          font-weight: 500;
      }

      #workspaces button.visible label {
          background: @transparent;
          border: ${borderWidth}px solid @background;
          color: @text-dark;
          font-weight: 900;
      }

      #workspaces button.active label {
          background: @background;
          border: ${borderWidth}px solid @background;
          color: @text-light;
          font-weight: 900;
      }

      #custom-poweroff {
          padding-right: 4px;
          color: @red;
      }

      #network.hostname {
          margin: 5px ${builtins.toString (gapSize + 2)}px 5px 0px;
          padding: 0px 7px;
          border-radius: ${halfCornerRadius}px;
          background: @blue;
          color: @text-dark;
      }

      #custom-vpn {
          margin-right: 3px;
      }

      #pulseaudio.source-muted {
          margin-right: 2px;
      }
    '';
}
