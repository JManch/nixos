{ inputs
, pkgs
, config
, nixosConfig
, lib
, ...
}:
let
  isWayland = lib.fetchers.isWayland config;
  cfg = config.modules.desktop.anyrun;
  desktopCfg = config.modules.desktop;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
{
  imports = [
    inputs.anyrun.homeManagerModules.default
  ];

  config = lib.mkIf (osDesktopEnabled && isWayland && cfg.enable) {
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
          ];
          width.fraction = 0.2;
          y.fraction = 0.35;
          hidePluginInfo = true;
          closeOnClick = true;
          # Blur background over waybar
          ignoreExclusiveZones = true;
        };
        extraCss =
          let
            cornerRadius = builtins.toString desktopCfg.style.cornerRadius;
          in
            /* css */ ''
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
              border-radius: ${cornerRadius}px;
              padding: 0.3rem;
            }
          '';
      };

    desktop.hyprland.settings =
      let
        modKey = config.modules.desktop.hyprland.modKey;
        anyrun = config.programs.anyrun.package;
      in
      lib.mkIf (config.modules.desktop.windowManager == "hyprland") {
        bindr = [
          "${modKey}, ${modKey}_L, exec, ${pkgs.procps}/bin/pkill anyrun || ${anyrun}/bin/anyrun"
        ];
        layerrule = [
          "blur, anyrun"
          "xray 0, anyrun"
        ];
      };
  };
}
