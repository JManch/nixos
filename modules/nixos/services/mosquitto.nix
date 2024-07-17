{ lib, config, ... }:
let
  inherit (lib) mkIf singleton;
  cfg = config.modules.services.mosquitto;
in
mkIf cfg.enable {
  services.mosquitto = {
    enable = true;
    listeners = singleton {
      address = "127.0.0.1";
      port = cfg.port;
      users = cfg.users;
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/mosquitto";
    user = "mosquitto";
    group = "mosquitto";
    mode = "700";
  };
}
