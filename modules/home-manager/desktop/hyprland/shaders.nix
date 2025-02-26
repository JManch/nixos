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
    mkIf
    concatMap
    concatLines
    any
    getExe
    getExe'
    ;
  inherit (osConfig.${ns}.core.device) monitors;
  isGammaCustom = any (m: m.gamma != 1.0) monitors;

  monitorGammaConditionals =
    (concatMap (
      m:
      if m.gamma == 1.0 then
        [ ]
      else
        [
          # WARNING: The monitor number here can be weird sometimes so might
          # need to manually set it for specific hosts
          # glsl
          ''
            if (wl_output == ${toString (m.number - 1)}) {
                vec4 pixColor = texture2D(tex, v_texcoord);
                pixColor.rgb = pow(pixColor.rgb, vec3(1.0 / ${toString m.gamma}));
                gl_FragColor = pixColor;
                return;
            }
          ''
        ]
    ) monitors)
    ++ [ "gl_FragColor = texture2D(tex, v_texcoord);" ];

  blankShader = # glsl
    ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;

      void main() {
          vec4 pixColor = texture2D(tex, v_texcoord);
          gl_FragColor = pixColor;
      }
    '';

  gammaShader =
    if isGammaCustom then # glsl
      ''
        precision mediump float;
        varying vec2 v_texcoord;
        uniform sampler2D tex;
        uniform int wl_output;

        void main() {
          ${concatLines monitorGammaConditionals}
        }
      ''
    else
      blankShader;

in
{
  xdg.configFile = {
    "hypr/shaders/monitorGamma.frag".text = gammaShader;
    "hypr/shaders/blank.frag".text = blankShader;
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
                ${cfg.disableShaders};
            else
                ${cfg.enableShaders};
            fi
          '';
    in
    mkIf isGammaCustom {
      decoration.screen_shader = "${config.xdg.configHome}/hypr/shaders/monitorGamma.frag";
      bind = [ "${cfg.modKey}, O, exec, ${toggleShader}" ];
    };
}
