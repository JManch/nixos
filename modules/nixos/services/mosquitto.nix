{ lib, config, ... }:
let
  inherit (lib) mkIf;
  inherit (config.age) secrets;
  inherit (config.modules.services) hass frigate;
  cfg = config.modules.services.mosquitto;
in
mkIf cfg.enable
{
  services.mosquitto = {
    enable = true;
    listeners = [{
      address = "127.0.0.1";
      port = cfg.port;

      users = {
        frigate = mkIf frigate.enable {
          acl = [ "readwrite #" ];
          hashedPasswordFile = secrets.mqttFrigatePassword.path;
        };

        hass = mkIf hass.enable {
          acl = [ "readwrite #" ];
          hashedPasswordFile = secrets.mqttHassPassword.path;
        };
      };
    }];
  };

  persistence.directories = [{
    directory = "/var/lib/mosquitto";
    user = "mosquitto";
    group = "mosquitto";
    mode = "700";
  }];
}
