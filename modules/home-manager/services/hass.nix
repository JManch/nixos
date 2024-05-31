{ lib
, pkgs
, config
, hostname
, osConfig
, ...
}:
let
  inherit (lib) mkIf getExe optionalString toLower replaceStrings;
  inherit (osConfig.device) hassIntegration;
  inherit (config.age.secrets) hassToken;

  curlCommand = { endpoint, data ? null }:
    ''${getExe pkgs.curl} -s \
      -H "Authorization: Bearer $(<${hassToken.path})" \
      -H "Content-Type: application/json" \
      ${optionalString (data != null) "-d '{${data}}'"} \
      ${hassIntegration.endpoint}/api/${endpoint}'';

  entityHostname = replaceStrings [ "-" ] [ "_" ] (toLower hostname);
  updateActiveState = state: pkgs.writeShellScript "hass-host-active-${state}" (curlCommand {
    data = ''"entity_id": "input_boolean.${entityHostname}_active"'';
    endpoint = "services/input_boolean/turn_${state}";
  });
in
mkIf osConfig.device.hassIntegration.enable
{
  # Set the active state entity on login and logout
  systemd.user.services.hass-active-state-init = {
    Unit = {
      Description = "Home assistant active host entity initialiser";
    };

    Service = {
      Type = "oneshot";
      ExecStart = (updateActiveState "on").outPath;
      ExecStop = (updateActiveState "off").outPath;
      RemainAfterExit = true;
    };

    Install.WantedBy = [ "default.target" ];
  };

  # Update the active state when locking
  modules.desktop.programs.swaylock = {
    postLockScript = (updateActiveState "off").outPath;
    postUnlockScript = (updateActiveState "on").outPath;
  };
}
