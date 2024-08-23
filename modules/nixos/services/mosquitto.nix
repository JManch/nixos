{ lib, config, ... }:
let
  inherit (lib) mkIf singleton;
  cfg = config.modules.services.mosquitto;
in
mkIf cfg.enable {
  services.mosquitto = {
    enable = true;
    listeners = singleton {
      port = cfg.port;
      users = cfg.users;
    };
  };

  networking.firewall.allowedTCPPorts = [ cfg.port ];

  persistence.directories = singleton {
    directory = "/var/lib/mosquitto";
    user = "mosquitto";
    group = "mosquitto";
    mode = "700";
  };
}
