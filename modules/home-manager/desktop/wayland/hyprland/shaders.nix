{ config
, nixosConfig
, lib
, ...
}:
let
  cfg = config.modules.desktop.hyprland;
in
# TODO: Modularise this shader config. Should probably have a gamma setting per monitor.
lib.mkIf (nixosConfig.usrEnv.desktop.compositor == "hyprland") {
  xdg.configFile."hypr/shaders/monitor1_gamma.frag".text =
    /*
      glsl
    */
    ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;
      uniform int output;

      void main() {
          // Apply gamma adjustment to monitor
          if (output == 1) {
              vec4 pixColor = texture2D(tex, v_texcoord);
              pixColor.rgb = pow(pixColor.rgb, vec3(1.0 / 0.75));
              gl_FragColor = pixColor;
          } else {
              gl_FragColor = texture2D(tex, v_texcoord);
          }
      }
    '';

  xdg.configFile."hypr/shaders/blank.frag".text =
    /*
      glsl
    */
    ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;

      void main() {
          vec4 pixColor = texture2D(tex, v_texcoord);
          gl_FragColor = pixColor;
      }
    '';

  wayland.windowManager.hyprland.settings.bind =
    let
      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
      blankShader = "${config.xdg.configHome}/hypr/shaders/blank.frag";
      shader = "${config.xdg.configHome}/hypr/shaders/monitor1_gamma.frag";
    in
    [
      "${cfg.modKey}, O, exec, ${hyprctl} keyword decoration:screen_shader ${blankShader}"
      "${cfg.modKey}SHIFT, O, exec, ${hyprctl} keyword decoration:screen_shader ${shader}"
    ];
}
