{ lib }:
{
  services.esphome = {
    enable = true;
    port = 6052;
    address = "localhost";
  };

  # Start the service manually when we want to flash firmware
  systemd.services.esphome.wantedBy = lib.mkForce [ ];

  ns.backups."esphome" = {
    backend = "restic";
    paths = [ "/var/lib/esphome" ];
    restore.pathOwnership."/var/lib/esphome" = {
      user = "esphome";
      group = "esphome";
    };
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/esphome";
    user = "esphome";
    group = "esphome";
    mode = "0750";
  };
}
