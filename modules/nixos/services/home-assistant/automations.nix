{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf head optional;
  inherit (secretCfg) devices;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) frigate;
  cfg = config.modules.services.hass;
  secretCfg = inputs.nix-resources.secrets.hass { inherit lib config; };

  frigateEntranceNotify = {
    alias = "Entrance Person Notify";
    description = "";
    use_blueprint = {
      path = "SgtBatten/Beta.yaml";
      input = {
        camera = "camera.driveway";
        notify_device = (head devices).id;
        notify_group = "All Notify Devices";
        base_url = "https://home-notif.${fqDomain}";
        title = "Security Alert";
        message = "A person was detected in the entrance";
        update_thumbnail = true;
        zone_filter = true;
        zones = [ "entrance" ];
        labels = [ "person" ];
      };
    };
  };
in
mkIf (cfg.enableInternal)
{
  services.home-assistant.config = {
    automation = optional frigate.enable frigateEntranceNotify;
  };
}
