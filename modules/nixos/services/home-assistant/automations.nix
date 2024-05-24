{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf utils head optional optionals attrValues;
  inherit (secretCfg) devices;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) frigate;
  cfg = config.modules.services.hass;
  secretCfg = inputs.nix-resources.secrets.hass { inherit lib config; };

  frigateEntranceNotify = {
    alias = "Entrance Person Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.driveway";
        notify_device = (head (attrValues devices)).id;
        notify_group = "All Notify Devices";
        base_url = "https://home-notif.${fqDomain}";
        group = "{{camera}}-frigate-notification";
        title = "Security Alert";
        message = "A person was detected in the entrance";
        update_thumbnail = true;
        alert_once = true;
        zone_filter = true;
        zones = [ "entrance" ];
        labels = [ "person" ];
      };
    };
  };

  frigateHighAlertNotify = map
    (camera: {
      alias = "High Alert ${utils.upperFirstChar camera} Notify";
      use_blueprint = {
        path = "SgtBatten/frigate_notifications.yaml";
        input = {
          camera = "camera.${camera}";
          state_filter = true;
          state_entity = "input_boolean.high_alert_surveillance";
          state_filter_states = [ "on" ];
          notify_device = (head (attrValues devices)).id;
          sticky = true;
          notify_group = "All Notify Devices";
          group = "{{camera}}-frigate-notification";
          base_url = "https://home-notif.${fqDomain}";
          title = "Security Alert";
          ios_live_view = "camera.${camera}";
          message = "A person was detected on the property";
          color = "#f44336";
          update_thumbnail = true;
        };
      };
    }) [ "driveway" "poolhouse" ];

  heatingTimeToggle = map
    (enable:
      let
        stringMode = if enable then "enable" else "disable";
        oppositeMode = if enable then "disable" else "enable";
      in
      {
        alias = "Heating ${if enable then "Enable" else "Disable"}";
        mode = "single";
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time";
            at = "input_datetime.heating_${stringMode}_time";
          }
        ];
        condition =
          let
            timeCond = {
              condition = "time";
              after = "input_datetime.heating_${stringMode}_time";
              before = "input_datetime.heating_${oppositeMode}_time";
            };
          in
          (optional (!enable) timeCond)
          ++
          (optional enable {
            condition = "and";
            conditions = [
              timeCond
              {
                condition = "state";
                entity_id = "input_boolean.heating_enabled";
                state = "on";
              }
            ];
          })
        ;
        action = [{
          service = "climate.set_hvac_mode";
          metadata = { };
          data = {
            hvac_mode = if enable then "heat" else "off";
          };
          target.entity_id = [
            "climate.joshua_thermostat"
            "climate.hallway"
          ];
        }];
      }) [ true false ];

  joshuaDehumidifierToggle = map
    (enable:
      {
        alias = "Joshua Dehumidifier ${if enable then "Enable" else "Disable"}";
        mode = "single";
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time";
            at = if enable then "21:00:00" else "10:00:00";
          }
        ];
        condition = [{
          condition = "and";
          conditions = [
            {
              condition = "time";
              after = if enable then "21:00:00" else "10:00:00";
              before = if enable then "10:00:00" else "21:00:00";
            }
          ] ++ optional enable {
            type = "is_plugged_in";
            condition = "device";
            device_id = devices.mobile_app_joshua_pixel_5.id;
            entity_id = devices.mobile_app_joshua_pixel_5.chargingStatusId;
            domain = "binary_sensor";
          };
        }];
        action = [{
          service = "humidifier.turn_${if enable then "on" else "off"}";
          metadata = { };
          data = { };
          target.entity_id = "humidifier.joshua_hygrostat";
        }];
      }) [ true false ];

  joshuaDehumidifierTankFull = [{
    alias = "Joshua Dehumidifier Full Notify";
    mode = "single";
    trigger = [{
      platform = "state";
      entity_id = "sensor.joshua_dehumidifier_tank_status";
      to = "Full";
      for.minutes = 1;
    }];
    condition = [ ];
    action = [{
      service = "notify.mobile_app_joshua_pixel_5";
      data = {
        title = "Dehumidifier";
        message = "Tank full";
      };
    }];
  }];

  joshuaDehumidifierMoldToggle = map
    (enable: {
      alias = "Joshua Dehumidifier ${if enable then "Enable" else "Disable"}";
      mode = "single";
      trigger = [{
        platform = "numeric_state";
        entity_id = [ "sensor.joshua_mold_indicator" ];
        above = mkIf enable 73;
        below = mkIf (!enable) 67;
        for.minutes = if enable then 0 else 30;
      }];
      condition = [ ];
      action = [
        {
          service = "switch.turn_${if enable then "on" else "off"}";
          target.entity_id = "switch.joshua_dehumidifier";
        }
      ];
    }) [ true false ];
in
mkIf (cfg.enableInternal)
{
  services.home-assistant.config = {
    automation = heatingTimeToggle
      # ++ joshuaDehumidifierToggle
      ++ joshuaDehumidifierMoldToggle
      ++ joshuaDehumidifierTankFull
      ++ optional frigate.enable frigateEntranceNotify
      ++ optionals frigate.enable frigateHighAlertNotify;

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

    input_boolean = {
      heating_enabled = {
        name = "Heating Enabled";
        icon = "mdi:heating-coil";
      };

      high_alert_surveillance = {
        name = "High Alert Surveillance";
        icon = "mdi:cctv";
      };
    };
  };
}
