{ config, lib, ... }: lib.mkIf (config.desktop.compositor == "hyprland") {
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
              pixColor.rgb = pow(pixColor.rgb, vec3(1.0 / 0.7));
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
}
