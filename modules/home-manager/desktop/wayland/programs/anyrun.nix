{ lib
, pkgs
, inputs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers utils;
  cfg = desktopCfg.programs.anyrun;
  desktopCfg = config.modules.desktop;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
  isWayland = fetchers.isWayland config;
in
{
  imports = [
    inputs.anyrun.homeManagerModules.default
  ];

  config = mkIf (osDesktopEnabled && isWayland && cfg.enable) {
    programs.anyrun =
      let
        color = base:
          inputs.nix-colors.lib.conversions.hexToRGBString "," config.colorscheme.palette.${base};
      in
      {
        enable = true;

        config = {
          width.fraction = 0.2;
          y.fraction = 0.35;
          hidePluginInfo = true;
          closeOnClick = true;
          # Blur background over waybar
          ignoreExclusiveZones = true;

          plugins = with utils.flakePkgs { inherit pkgs inputs; } "anyrun"; [
            applications
            websearch
          ];
        };
        extraCss =
          let
            cornerRadius = toString desktopCfg.style.cornerRadius;
          in
            /*css*/ ''

            * {
              all: unset;
              font-size: 2rem;
              font-family: ${desktopCfg.style.font.family};
            }

            #window,
            #match,
            #plugin,
            #main {
              background: transparent;
            }

            #match.activatable {
              border-radius: ${cornerRadius}px;
              padding: 0.3rem 0.9rem;
               margin-top: 0.01rem;
            }

            #match.activatable:last-child {
              margin-bottom: 0.6rem;
            }

            #match:selected label {
              font-weight: 600;
            }

            #entry {
              margin: 0.5rem;
              padding: 0.3rem 1rem;
            }

            box#main {
              background: rgb(${color "base00"});
              border: 2px solid rgb(${color "base0D"});
              border-radius: ${cornerRadius}px;
              padding: 0.3rem;
            }

          '';
      };

    desktop.hyprland.settings =
      let
        inherit (desktopCfg.hyprland) modKey;
      in
      {
        bindr = [
          "${modKey}, ${modKey}_L, exec, ${pkgs.procps}/bin/pkill anyrun || anyrun"
        ];

        layerrule = [
          "blur, anyrun"
          "xray 0, anyrun"
        ];
      };
  };
}
