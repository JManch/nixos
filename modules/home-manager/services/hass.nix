{
  lib,
  pkgs,
  config,
  hostname,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    getExe'
    optionalString
    toLower
    ;
  inherit (osConfig'.device) hassIntegration;
  inherit (config.age.secrets) hassToken;

  curlCommand =
    {
      endpoint,
      data ? null,
    }:
    ''
      ${getExe pkgs.curl} -s --max-time 1 \
            -H "Authorization: Bearer $(<"${hassToken.path}")" \
            -H "Content-Type: application/json" \
            ${optionalString (data != null) "-d '{${data}}'"} \
            ${hassIntegration.endpoint}/api/${endpoint}'';

  updateActiveState =
    state:
    pkgs.writeShellScript "hass-host-active-${state}" (curlCommand {
      data = ''"active": "${state}"'';
      endpoint = "webhook/${toLower hostname}-active";
    });
in
mkIf (osConfig'.device.hassIntegration.enable or false) {
  modules.services.hass.curlCommand = curlCommand;

  systemd.user.services.hass-active-heartbeat = {
    Unit = {
      Description = "Home assistant host active heartbeat";
    };

    Service = {
      ExecStart = pkgs.writeShellScript "hass-active-heartbeat" ''
        while true
        do
          ${updateActiveState "on"}
          ${getExe' pkgs.coreutils "sleep"} 60
        done
      '';
      ExecStopPost = (updateActiveState "off").outPath;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Update the active state when locking
  modules.desktop.programs.swaylock = {
    postLockScript = "systemctl stop --user hass-active-heartbeat";
    postUnlockScript = "systemctl start --user hass-active-heartbeat";
  };
}
