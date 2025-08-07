{ lib, config }:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.system) impermanence;
in
[
  {
    enableOpt = false;

    # On laptops we would rather set timezone imperatively with `timedatectl` for
    # when we are away from home
    time.timeZone = if device.type == "laptop" then null else "Europe/London";
  }

  (mkIf (impermanence.enable && config.time.timeZone == null) {
    # Ugly persistence implementation due to https://github.com/nix-community/impermanence/issues/153
    system.activationScripts."setup-localtime" = # bash
      ''
        if [ ! -e "/etc/localtime" ] && [ -L "/persist/etc/localtime" ]; then
          cp -d /persist/etc/localtime /etc/localtime
        fi
      '';

    systemd.services."persist-localtime" = {
      description = "Persist /etc/localtime";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStop = "cp -d /etc/localtime /persist/etc/localtime";
      };
      wantedBy = [ "multi-user.target" ];
    };
  })
]
