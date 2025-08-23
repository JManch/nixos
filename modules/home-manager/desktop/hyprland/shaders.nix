{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    concatMapStringsSep
    optionalString
    mkOption
    types
    getExe
    getExe'
    ;
  inherit (osConfig.${ns}.core.device) isGammaCustom monitors;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
in
{
  conditions = [ isGammaCustom ];

  opts = {
    enableShaders = mkOption {
      type = types.str;
      readOnly = true;
      default =
        if isGammaCustom then
          "${hyprctl} keyword decoration:screen_shader '${cfg.shaderDir}/monitorGamma.frag' >/dev/null"
        else
          "";
      description = "Command to enable Hyprland screen shaders";
    };

    disableShaders = mkOption {
      type = types.str;
      readOnly = true;
      default =
        if isGammaCustom then
          "${hyprctl} keyword decoration:screen_shader '${cfg.shaderDir}/blank.frag' >/dev/null"
        else
          "";
      description = "Command to disable Hyprland screen shaders";
    };
  };

  xdg.configFile = {
    "hypr/shaders/monitorGamma.frag".text = # glsl
      ''
        #version 300 es
        precision mediump float;

        uniform sampler2D tex;
        uniform int wl_output;

        in highp vec2 v_texcoord;

        layout(location = 0) out vec4 fragColor;

        ${concatMapStringsSep "\n" (
          m:
          optionalString (
            m.gamma != 1.0
          ) "const float GAMMA_${toString m.number} = 1.0 / ${toString m.gamma};"
        ) monitors}

        void main() {
          vec4 pixColor = texture(tex, v_texcoord);
          ${
            (concatMapStringsSep "\n" (
              m:
              optionalString (m.gamma != 1.0)
                # WARNING: The monitor number here can be weird sometimes so might
                # need to manually set it for specific hosts
                # glsl
                ''
                  if (wl_output == ${toString (m.number - 1)}) {
                      pixColor.rgb = pow(pixColor.rgb, vec3(GAMMA_${toString m.number}));
                    }
                ''
            ) monitors)
          }
          fragColor = pixColor;
        }
      '';

    "hypr/shaders/blank.frag".text = # glsl
      ''
        #version 300 es
        precision mediump float;

        uniform sampler2D tex;

        in highp vec2 v_texcoord;

        layout(location = 0) out vec4 fragColor;

        void main() {
          fragColor = texture(tex, v_texcoord);
        }
      '';
  };

  wayland.windowManager.hyprland.settings =
    let
      hyprctl = getExe' pkgs.hyprland "hyprctl";
      jaq = getExe pkgs.jaq;
      toggleShader =
        pkgs.writeShellScript "hypr-toggle-shader" # bash
          ''
            shader=$(${hyprctl} getoption decoration:screen_shader -j | ${jaq} -r '.str')
            if [[ $shader == "${cfg.shaderDir}/monitorGamma.frag" ]]; then
                ${cfg.disableShaders}
            else
                ${cfg.enableShaders}
            fi
          '';
    in
    {
      decoration.screen_shader = "${config.xdg.configHome}/hypr/shaders/monitorGamma.frag";
      bind = [ "${cfg.modKey}, O, exec, ${toggleShader}" ];
    };
}
