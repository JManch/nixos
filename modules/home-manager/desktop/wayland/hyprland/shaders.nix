{ config
, nixosConfig
, lib
, pkgs
, ...
}:
let
  desktopCfg = config.modules.desktop;
  cfg = config.modules.desktop.hyprland;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
# TODO: Modularise this shader config. Should probably have a gamma setting per monitor.
lib.mkIf (osDesktopEnabled && desktopCfg.windowManager == "hyprland") {
  xdg.configFile."hypr/shaders/monitor1_gamma.frag".text =
    /*
      glsl
    */
    ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;
      uniform int monitor;

      void main() {
          // Apply gamma adjustment to monitor

          // NOTE: Had to apply a patch to hyprland which renames output to
          // monitor The issue coincided with my GPU upgrade from NVIDIA -> AMD
          // so that might be related

          // LOG ERROR
          // [wlr] [GLES2] 0:4(13): error: illegal use of reserved word `output'
          // [wlr] [GLES2] 0:4(13): error: syntax error, unexpected ERROR_TOK, expecting ',' or ';'

          if (monitor == 1) {
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
      getShader = "$(${hyprctl} getoption decoration:screen_shader -j | ${pkgs.jaq}/bin/jaq -r '.str')";
      shaderToggle = "if [[ ${getShader} == \"${shader}\" ]]; then ${pkgs.coreutils}/bin/echo \"${blankShader}\"; else ${pkgs.coreutils}/bin/echo \"${shader}\"; fi";
    in
    [
      "${cfg.modKey}, O, exec, ${hyprctl} keyword decoration:screen_shader $(${shaderToggle})"
    ];
}
