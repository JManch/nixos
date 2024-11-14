{
  ns,
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
    optionalString
    toLower
    ;
  inherit (osConfig'.${ns}.device) hassIntegration;
  inherit (config.age.secrets) hassToken;

  curlCommand =
    {
      endpoint,
      data ? null,
    }:
    ''
      curl -s --max-time 1 \
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
mkIf (osConfig'.${ns}.device.hassIntegration.enable or false) {
  ${ns} = {
    services.hass.curlCommand = curlCommand;

    # Update the active state when locking
    desktop.programs.locking = {
      postLockScript = "systemctl stop --user hass-active-heartbeat";
      postUnlockScript = "systemctl start --user hass-active-heartbeat";
    };
  };

  systemd.user.services.hass-active-heartbeat = {
    Unit = {
      Description = "Home assistant host active heartbeat";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Slice = [ "background-graphical.slice" ];
      ExecStart = pkgs.writeShellScript "hass-active-heartbeat" ''
        while true
        do
          ${updateActiveState "on"}
          sleep 60
        done
      '';
      ExecStopPost = (updateActiveState "off").outPath;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
