{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf optional;
  inherit (config.modules.services) frigate;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (secretCfg.lovelaceConfig) heating room1;

  cfg = config.modules.services.hass;
  secretCfg = inputs.nix-resources.secrets.hass { inherit lib config; };

  home = {
    title = "Home";
    cards = [
      {
        type = "vertical-stack";
        cards = [
          {
            type = "weather-forecast";
            entity = "weather.forecast_home";
            forecast_type = "daily";
          }
          { type = "energy-distribution"; }
        ];
      }
      {
        type = "entities";
        entities = [
          { entity = "sensor.outdoor_temperature"; name = "Temperature"; }
          { entity = "sensor.outdoor_humidity"; name = "Humidity"; }
          { entity = "sensor.outdoor_thermal_comfort_absolute_humidity"; name = "Absolute Humidity"; }
          { entity = "sensor.outdoor_thermal_comfort_dew_point"; name = "Dew Point"; }
          { entity = "sensor.outdoor_thermal_comfort_dew_point_perception"; name = "Dew Point Perception"; }
          { entity = "sensor.outdoor_thermal_comfort_frost_point"; name = "Frost Point"; }
          { entity = "sensor.outdoor_thermal_comfort_frost_risk"; name = "Frost Risk"; }
          { entity = "sensor.outdoor_thermal_comfort_heat_index"; name = "Heat Index"; }
          { entity = "sensor.outdoor_thermal_comfort_humidex"; name = "Humidex"; }
          { entity = "sensor.outdoor_thermal_comfort_humidex_perception"; name = "Humidex Perception"; }
          { entity = "sensor.outdoor_thermal_comfort_moist_air_enthalpy"; name = "Moist Air Enthalpy"; }
          { entity = "sensor.outdoor_thermal_comfort_relative_strain_perception"; name = "Relative Strain"; }
          { entity = "sensor.outdoor_thermal_comfort_summer_scharlau_perception"; name = "Summer Scharlau"; }
          { entity = "sensor.outdoor_thermal_comfort_summer_simmer_index"; name = "Summer Simmer Index"; }
          { entity = "sensor.outdoor_thermal_comfort_summer_simmer_perception"; name = "Summer Simmer Perception"; }
          { entity = "sensor.outdoor_thermal_comfort_thoms_discomfort_perception"; name = "Thoms Discomfort"; }
          { entity = "sensor.outdoor_thermal_comfort_winter_scharlau_perception"; name = "Winter Scharlau"; }
        ];
      }
    ];
  };

  lounge = {
    title = "Lounge";
    path = "lounge";
    cards = [
      {
        type = "vertical-stack";
        cards = [
          {
            type = "light";
            entity = "light.lounge";
            name = "Lounge";
          }
          {
            type = "picture-elements";
            camera_image = "camera.lounge_floorplan";
            elements =
              let
                lightIcon = lightID: posTop: posLeft: {
                  type = "state-icon";
                  entity = "light.lounge_spot_ceiling_${lightID}";
                  tap_action.action = "toggle";
                  style = {
                    top = posTop;
                    left = posLeft;
                    background = "rgba(0, 0, 0, 0.8)";
                    border-radius = "50%";
                  };
                };
              in
              [
                (lightIcon "01" "65%" "85%")
                (lightIcon "02" "25%" "85%")
                (lightIcon "03" "45%" "72%")
                (lightIcon "04" "65%" "59%")
                (lightIcon "05" "25%" "59%")
                (lightIcon "06" "65%" "39%")
                (lightIcon "07" "25%" "39%")
                (lightIcon "08" "45%" "26%")
                (lightIcon "09" "65%" "13%")
                (lightIcon "10" "25%" "13%")
              ];
          }
        ];
      }
      { type = "thermostat"; entity = "climate.lounge"; }
    ];
  };

  joshuaRoom = {
    title = "Joshua's Room";
    path = "joshua-room";
    cards = [
      {
        type = "vertical-stack";
        cards = [
          { type = "light"; entity = "light.joshua_room"; }
          {
            type = "entities";
            state_color = true;
            entities = [
              { entity = "light.joshua_lamp_floor_01"; }
              { entity = "light.joshua_strip_bed_01"; }
              { entity = "light.joshua_lamp_bed_01"; }
              { entity = "light.joshua_bulb_ceiling_01"; }
              { entity = "light.joshua_play_desk_01"; }
              { entity = "light.joshua_play_desk_02"; }
            ];
          }
          {
            type = "entities";
            state_color = true;
            entities = [
              { entity = "switch.adaptive_lighting_joshua_room"; name = "Adaptive Lighting"; }
              { entity = "switch.adaptive_lighting_adapt_brightness_joshua_room"; name = "Adapt Brightness"; }
              { entity = "switch.adaptive_lighting_adapt_color_joshua_room"; name = "Adapt Color"; }
              { entity = "switch.adaptive_lighting_sleep_mode_joshua_room"; name = "Sleep Mode"; }
              { entity = "input_boolean.joshua_room_wake_up_lights"; name = "Wake Up Lights"; }
            ];
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            name = "Temperature";
            graph = "line";
            type = "sensor";
            entity = "sensor.joshua_temperature";
            detail = 2;
          }
          {
            name = "Humidity";
            graph = "line";
            type = "sensor";
            entity = "sensor.joshua_humidity";
            detail = 2;
          }
          {
            type = "entities";
            entities = [
              { entity = "sensor.joshua_thermal_comfort_summer_scharlau_perception"; name = "Summer Scharlau"; }
              { entity = "sensor.joshua_thermal_comfort_thoms_discomfort_perception"; name = "Thoms Discomfort"; }
            ];
          }
        ];
      }
      {
        type = "history-graph";
        entities = [{ entity = "binary_sensor.ncase_m1_active"; name = "NCASE-M1"; }];
      }
      {
        title = "Dehumidifier";
        state_color = true;
        type = "entities";
        entities = [
          { entity = "switch.joshua_dehumidifier"; name = "Enabled"; }
          { entity = "sensor.joshua_dehumidifier_tank_status"; name = "Tank Status"; }
          { entity = "sensor.joshua_dehumidifier_energy"; name = "Energy"; }
          { entity = "sensor.joshua_dehumidifier_power"; name = "Power"; }
          { entity = "sensor.joshua_mold_indicator"; name = "Mold Indicator"; }
          { entity = "sensor.joshua_critical_temperature"; name = "Critical Temperature"; }
          { entity = "sensor.joshua_dew_point"; name = "Dew Point"; }
        ];
      }
    ];
  };

  garden = {
    path = "garden";
    title = "Garden";
    cards = [
      {
        type = "vertical-stack";
        cards = [
          {
            graph = "line";
            type = "sensor";
            detail = 2;
            entity = "sensor.outdoor_temperature";
            name = "Temperature";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.outdoor_humidity";
            detail = 2;
            name = "Humidity";
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            entities = [
              { entity = "lawn_mower.lewis"; }
              { entity = "switch.lewis_enable_schedule"; }
              { entity = "sensor.lewis_mode"; }
              { entity = "sensor.lewis_next_start"; }
              { entity = "sensor.lewis_number_of_charging_cycles"; }
              { entity = "sensor.lewis_number_of_collisions"; }
              { entity = "sensor.lewis_total_charging_time"; }
              { entity = "sensor.lewis_total_cutting_time"; }
              { entity = "sensor.lewis_total_drive_distance"; }
              { entity = "sensor.lewis_total_running_time"; }
              { entity = "sensor.lewis_total_searching_time"; }
            ];
            type = "entities";
          }
          {
            detail = 1;
            entity = "sensor.lewis_battery";
            graph = "line";
            type = "sensor";
          }
        ];
      }
    ];
  };

  power = {
    title = "Power";
    path = "power";
    cards = [
      { type = "energy-distribution"; }
      {
        type = "vertical-stack";
        cards = [
          {
            graph = "line";
            type = "sensor";
            detail = 2;
            entity = "sensor.powerwall_load_power";
            hours_to_show = 12;
            name = "House Power";
          }
          {
            type = "history-graph";
            hours_to_show = 12;
            logarithmic_scale = false;

            entities = [
              { entity = "binary_sensor.washing_machine_running"; name = "Washing M"; }
              { entity = "binary_sensor.dishwasher_running"; name = "Dishwasher"; }
            ];
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.lights_on_count";
            detail = 2;
            hours_to_show = 12;
            name = "Lights On";
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            graph = "line";
            type = "sensor";
            detail = 2;
            entity = "sensor.powerwall_site_power";
            hours_to_show = 12;
            name = "Site Power";
          }
          {
            type = "history-graph";
            entities = [{ entity = "binary_sensor.powerwall_grid_charge_status"; }];
            hours_to_show = 12;
            logarithmic_scale = false;
          }
          {
            type = "entity";
            state_color = true;
            name = "Grid Charge Status";
            entity = "binary_sensor.powerwall_grid_charge_status";
          }
          {
            type = "entities";
            state_color = true;
            entities = [
              { entity = "sensor.powerwall_backup_reserve"; name = "Battery Reserve"; }
              { entity = "binary_sensor.powerwall_grid_status"; name = "Grid Status"; }
              { entity = "switch.powerwall_off_grid_operation"; name = "Off-grid Operation"; }
            ];
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            graph = "line";
            type = "sensor";
            detail = 2;
            entity = "sensor.powerwall_battery_power";
            hours_to_show = 12;
            name = "Battery Power";
          }
          {
            type = "history-graph";
            entities = [{ entity = "binary_sensor.powerwall_battery_charge_status"; }];
            hours_to_show = 12;
          }
          {
            type = "entity";
            state_color = true;
            entity = "binary_sensor.powerwall_battery_charge_status";
            name = "Battery Charge Status";
          }
          {
            type = "entities";
            state_color = true;

            entities = [
              { entity = "sensor.powerwall_gateway_battery_capacity"; name = "Battery Capacity"; }
              { entity = "sensor.powerwall_gateway_battery_remaining"; name = "Battery Remaining"; }
              { entity = "sensor.powerwall_gateway_battery_voltage"; name = "Battery Voltage"; }
              { entity = "sensor.powerwall_battery_remaining_time"; name = "Battery Time"; }
            ];
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            graph = "line";
            type = "sensor";
            detail = 2;
            entity = "sensor.powerwall_solar_power";
            hours_to_show = 12;
            name = "Solar Power";
          }
          {
            type = "entities";
            state_color = true;
            entities = [
              { entity = "sensor.power_production_now"; name = "Estimated Production Now"; }
              { entity = "sensor.energy_production_today"; name = "Estimated Production Today"; }
              { entity = "sensor.energy_production_tomorrow"; name = "Estimated Production Tomorrow"; }
              { entity = "sensor.power_highest_peak_time_today"; name = "Peak Time Today"; }
            ];
          }
        ];
      }
      {
        type = "vertical-stack";
        cards = [
          {
            chart_type = "line";
            period = "hour";
            type = "statistics-graph";
            entities = [
              { entity = "sensor.powerwall_site_import_cost"; name = "Month Import Cost"; }
              { entity = "sensor.powerwall_site_export_compensation"; name = "Month Export Compensation"; }
            ];
            stat_types = [ "sum" ];
          }
          {
            chart_type = "line";
            period = "hour";
            type = "statistics-graph";
            entities = [{ entity = "sensor.powerwall_aggregate_cost"; name = "Month Aggregate Cost"; }];
            stat_types = [ "sum" ];
          }
        ];
      }
    ];
  };

  surveillance =
    let
      frigateCameraCard = camera: {
        type = "custom:frigate-card";
        performance.profile = "low";
        cameras = [{
          camera_entity = "camera.${camera}";
          frigate.url = "https://cctv.${fqDomain}";
          live_provider = "go2rtc";
          go2rtc.modes = [ (if frigate.webrtc.enable then "webrtc" else "mse") ];
        }];
        live = {
          transition_effect = "none";
          show_image_during_load = true;
        };
        menu = {
          style = "hover-card";
          buttons = {
            cameras.enabled = false;
            fullscreen.enabled = true;
            timeline.enabled = true;
            expand.enabled = false;
          };
        };
      };

      frigateCameraStats = camera: {
        type = "vertical-stack";
        cards = [
          {
            type = "entities";
            state_color = true;
            entities = [
              { entity = "binary_sensor.${camera}_motion"; }
              { entity = "binary_sensor.${camera}_person_occupancy"; }
              { entity = "sensor.${camera}_person_count"; }
              { entity = "switch.${camera}_motion"; }
              { entity = "switch.${camera}_detect"; }
            ];
          }
          {
            show_state = true;
            show_name = true;
            camera_view = "auto";
            type = "picture-entity";
            entity = "image.${camera}_person";
          }
        ];
      };
    in
    {
      title = "Surveillance";
      path = "surveillance";
      cards = [
        {
          type = "vertical-stack";
          cards = [
            (frigateCameraCard "driveway")
            (frigateCameraCard "poolhouse")
            {
              type = "entities";
              entities = [{ entity = "input_boolean.high_alert_surveillance"; }];
              state_color = true;
            }
          ];
        }
        (frigateCameraStats "driveway")
        (frigateCameraStats "poolhouse")
      ];
    };

in
mkIf cfg.enableInternal
{
  services.home-assistant = {
    lovelaceConfig = {
      title = "Dashboard";

      views = [
        home
        power
      ]
      ++ optional frigate.enable surveillance
      ++
      [
        heating
        lounge
        joshuaRoom
        room1
        garden
      ];
    };
  };
}
