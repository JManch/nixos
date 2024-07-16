{ lib, config, ... }:
let
  inherit (lib) mkIf;
  cfg = config.modules.services.mosquitto;
in
mkIf cfg.enable {
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
        port = cfg.port;
        users = cfg.users;
      }
    ];
  };

  persistence.directories = [
    {
      directory = "/var/lib/mosquitto";
      user = "mosquitto";
      group = "mosquitto";
      mode = "700";
    }
  ];
}
