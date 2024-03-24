{ lib, config, ... }:
let
  inherit (lib) mkIf;
  inherit (config.age) secrets;
  inherit (config.modules.services) home-assistant frigate;
  cfg = config.modules.services.mosquitto;
in
mkIf cfg.enable
{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
        port = 1883;

        users = {
          frigate = mkIf frigate.enable {
            acl = [ "readwrite #" ];
            hashedPasswordFile = secrets.mqttFrigatePassword.path;
          };

          hass = mkIf home-assistant.enable {
            acl = [ "readwrite #" ];
            hashedPasswordFile = secrets.mqttHassPassword.path;
          };
        };
      }
    ];
  };
}
