{ inputs
, pkgs
, config
, osConfig
, lib
, ...
}:
let
  isWayland = lib.validators.isWayland osConfig;
  cfg = config.modules.desktop.anyrun;
in
{
  imports = [
    inputs.anyrun.homeManagerModules.default
  ];

  config = lib.mkIf (isWayland && cfg.enable) {
    programs.anyrun =
      let
        color = base:
          inputs.nix-colors.lib.conversions.hexToRGBString "," config.colorscheme.colors.${base};
      in
      {
        enable = true;
        config = {
          plugins = with inputs.anyrun.packages.${pkgs.system}; [
            applications
            websearch
            shell
          ];
          width.fraction = 0.2;
          y.fraction = 0.3;
          hidePluginInfo = true;
          closeOnClick = true;
        };
        extraCss =
          /*
        css
          */
          ''
            * {
              all: unset;
              font-size: 2rem;
              font-family: ${config.modules.desktop.font.family};
            }

            #window,
            #match,
            #plugin,
            #main {
              background: transparent;
            }

            #match.activatable {
              border-radius: 10px;
              padding: 0.3rem 0.9rem;
               margin-top: 0.01rem;
            }

            #match.activatable:last-child {
              margin-bottom: 0.6rem;
            }

            /* #match:selected { */
            /*   background: rgb(${color "base01"}); */
            /* } */

            #match:selected label {
              /* text-decoration: underline; */
              font-weight: 600;
            }

            #entry {
              margin: 0.5rem;
              padding: 0.3rem 1rem;
            }

            box#main {
              background: rgb(${color "base00"});
              border: 2px solid rgb(${color "base0D"});
              border-radius: 10px;
              padding: 0.3rem;
            }
          '';
      };

    wayland.windowManager.hyprland.settings =
      let
        modKey = config.modules.desktop.hyprland.modKey;
      in
      {
        bindr = [
          "${modKey}, ${modKey}_L, exec, anyrun"
        ];
        layerrule = [
          "blur, anyrun"
          "xray 0, anyrun"
        ];
      };
  };
}
