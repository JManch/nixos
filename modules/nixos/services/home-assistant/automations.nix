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
      path = "SgtBatten/frigate_notifications.yaml";
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

  heatingTimeToggle = mode:
    let
      oppositeMode = if mode == "enable" then "disable" else "enable";
    in
    {
      alias = "${if mode == "enable" then "Enable" else "Disable"} Heating";
      mode = "single";
      trigger = [
        {
          platform = "homeassistant";
          event = "start";
        }
        {
          platform = "time";
          at = "input_datetime.heating_${mode}_time";
        }
      ];
      condition = [
        {
          condition = "time";
          after = "input_datetime.heating_${mode}_time";
          before = "input_datetime.heating_${oppositeMode}_time";
        }
      ];
      action = [
        {
          service = "climate.set_hvac_mode";
          metadata = { };
          data = {
            hvac_mode = if mode == "enable" then "heat" else "off";
          };
          target.entity_id = [
            "climate.joshua_room_thermostat"
            "climate.hallway"
          ];
        }
      ];
    };
in
mkIf (cfg.enableInternal)
{
  services.home-assistant.config = {
    automation = [
      (heatingTimeToggle "enable")
      (heatingTimeToggle "disable")
    ] ++ optional frigate.enable frigateEntranceNotify;

    input_datetime = {
      heating_disable_time = {
        name = "Heating Disable Time";
        has_time = true;
      };

      heating_enable_time = {
        name = "Heating Enable Time";
        has_time = true;
      };
    };
  };
}
