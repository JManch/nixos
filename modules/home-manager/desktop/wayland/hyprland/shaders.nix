{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf concatMap concatLines fetchers getExe getExe';
  inherit (osConfig.device) monitors;
  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  osDesktopEnabled = osConfig.modules.system.desktop.enable;
  isGammaCustom = fetchers.isGammaCustom osConfig;

  monitorGammaConditionals = (concatMap
    (m:
      if m.gamma == 1.0 then [ ] else [
        # WARNING: The monitor number here can be weird sometimes so might
        # need to manually set it for specific hosts
        /*glsl*/
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
    monitors) ++ [ "gl_FragColor = texture2D(tex, v_texcoord);" ];

  blankShader = /*glsl*/ ''

    precision mediump float;
    varying vec2 v_texcoord;
    uniform sampler2D tex;

    void main() {
        vec4 pixColor = texture2D(tex, v_texcoord);
        gl_FragColor = pixColor;
    }

  '';

  gammaShader =
    if isGammaCustom then /*glsl*/ ''

      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;
      uniform int wl_output;

      void main() {
        ${concatLines monitorGammaConditionals}
      }

    '' else blankShader;

in
mkIf (osDesktopEnabled && desktopCfg.windowManager == "Hyprland") {
  xdg.configFile."hypr/shaders/monitorGamma.frag".text = gammaShader;
  xdg.configFile."hypr/shaders/blank.frag".text = blankShader;

  wayland.windowManager.hyprland.settings =
    let
      hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
      jaq = getExe pkgs.jaq;
      toggleShader = pkgs.writeShellScript "hypr-toggle-shader" /*bash*/ ''

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

  modules.desktop.programs.swaylock = {
    preLockScript = ''
      ${cfg.disableShaders}
    '';

    postLockScript = ''
      (${getExe' pkgs.coreutils "sleep"} 0.1; ${cfg.enableShaders}) &
    '';
  };
}
