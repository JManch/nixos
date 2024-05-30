{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf getExe getExe';
  inherit (osConfig.device) hassIntegration;
  inherit (config.age.secrets) hassToken;
  cfg = config.modules.services.hass;
  curl = getExe pkgs.curl;
  bc = getExe' pkgs.bc "bc";
  jaq = getExe pkgs.jaq;

  setLights = state:
    let
      curlLights = ''
        ${curl} -s \
          -H "Authorization: Bearer $(<${hassToken.path})" \
          -H "Content-Type: application/json" \
          -d '{"entity_id": "light.joshua_room"}' \
          ${hassIntegration.endpoint}/api/services/light/turn_${state}
      '';
    in
    pkgs.writeShellScript "joshua_lights_${state}" ''
      ${if (state == "on") then /*bash*/ ''
        power=$(${curl} -s \
          -H "Authorization: Bearer $(<${hassToken.path})" \
          -H "Content-Type: application/json" \
          ${hassIntegration.endpoint}/api/states/sensor.powerwall_solar_power \
          | ${jaq} -r .state)

        if [ "$(echo "$power < ${toString cfg.solarLightThreshold}" | ${bc})" -eq 1 ]; then
          ${curlLights}
        fi
      '' else ''
        ${curlLights}
      ''}
    '';
in
mkIf osConfig.device.hassIntegration.enable
{
  modules.desktop.programs.swaylock = {
    postLockScript = /*bash*/ ''
      (
        sleep 5
        if [ -e "$lockfile" ]; then
          ${setLights "off"}
        fi
      ) &
    '';

    postUnlockScript = (setLights "on").outPath;
  };
}
