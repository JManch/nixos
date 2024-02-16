{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  desktopCfg = config.modules.desktop;
  cfg = config.modules.desktop.hyprland;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
  isGammaCustom = lib.fetchers.isGammaCustom osConfig;
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  shaderDir = "${config.xdg.configHome}/hypr/shaders";

  #  NOTE: Had to apply a patch to hyprland which renames output to
  # monitor The issue coincided with my GPU upgrade from NVIDIA -> AMD
  # so that might be why
  # LOG ERROR
  # [wlr] [GLES2] 0:4(13): error: illegal use of reserved word `output'
  # [wlr] [GLES2] 0:4(13): error: syntax error, unexpected ERROR_TOK, expecting ',' or ';'

  monitorGammaConditionals = (lib.lists.concatMap
    (m:
      if m.gamma == 1.0 then [ ] else [
        # WARNING: The monitor number here can be weird sometimes so might
        # need to manually set it for specific hosts
        /* glsl */
        ''
          if (wl_output == ${toString (m.number - 1)}) {
              vec4 pixColor = texture2D(tex, v_texcoord);
              pixColor.rgb = pow(pixColor.rgb, vec3(1.0 / ${toString m.gamma}));
              gl_FragColor = pixColor;
              return;
          }
        ''
      ]
    )
    osConfig.device.monitors) ++ [ "gl_FragColor = texture2D(tex, v_texcoord);" ];

  blankShader = /* glsl */ ''
    precision mediump float;
    varying vec2 v_texcoord;
    uniform sampler2D tex;

    void main() {
        vec4 pixColor = texture2D(tex, v_texcoord);
        gl_FragColor = pixColor;
    }
  '';

  gammaShader = /* glsl */
    if isGammaCustom then ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;
      uniform int wl_output;

      void main() {
        ${builtins.concatStringsSep ("\n") monitorGammaConditionals}
      }
    '' else blankShader;

in
lib.mkIf (osDesktopEnabled && desktopCfg.windowManager == "hyprland") {

  xdg.configFile."hypr/shaders/monitorGamma.frag".text = gammaShader;
  xdg.configFile."hypr/shaders/blank.frag".text = blankShader;

  modules.desktop.util =
    {
      enableShaders = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/monitorGamma.frag";
      disableShaders = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/blank.frag";
    };

  wayland.windowManager.hyprland.settings =
    let
      toggleShader = with config.modules.desktop.util;
        pkgs.writeShellScript "hypr-toggle-shader" ''
          shader=$(${hyprctl} getoption decoration:screen_shader -j | ${pkgs.jaq}/bin/jaq -r '.str')
          if [[ $shader == "${shaderDir}/monitorGamma.frag" ]]; then
              ${disableShaders};
          else
              ${enableShaders};
          fi
        '';
    in
    lib.mkIf isGammaCustom {
      bind =
        [
          "${cfg.modKey}, O, exec, ${toggleShader.outPath}"
        ];
      decoration.screen_shader = "${config.xdg.configHome}/hypr/shaders/monitorGamma.frag";
    };
}
