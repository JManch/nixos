{ lib
, config
, username
, ...
}:
let
  cfg = config.modules.system.bluetooth;
in
lib.mkIf cfg.enable
{
  hardware.bluetooth = {
    enable = true;
  };

  services.blueman.enable = true;

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/blueman"
    ];
  };
}
