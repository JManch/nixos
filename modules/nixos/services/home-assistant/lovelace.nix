{
  lib,
  cfg,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    optionals
    singleton
    attrNames
    mapAttrs
    filterAttrs
    concatMap
    mapAttrsToList
    ;
  inherit (lib.${ns}) upperFirstChar;
  inherit (config.${ns}.services) frigate;
  inherit (secrets.general) people userIds peopleList;

  secrets = inputs.nix-resources.secrets.homeAssistant { inherit lib config; };
  cameras = attrNames config.services.frigate.settings.cameras;
  upperPeople = mapAttrs (_: p: upperFirstChar p) people;

  home = {
    title = "Home";
    path = "home";
    type = "sections";
    max_columns = 1;
    badges =
      [
        {
          type = "entity";
          display_type = "complete";
          entity = "sensor.ac_on_count";
          name = "HVAC Running";
          color = "purple";
          visibility = singleton {
            condition = "numeric_state";
            entity = "sensor.ac_on_count";
            above = 0;
          };
          tap_action = {
            action = "navigate";
            navigation_path = "/lovelace/hvac";
          };
        }
        {
          type = "entity";
          entity = "switch.lewis_enable_schedule";
          icon = "mdi:robot-mower";
          name = "Disabled";
          state_content = "name";
          color = "red";
          visibility = singleton {
            condition = "state";
            entity = "switch.lewis_enable_schedule";
            state = "off";
          };
        }
        {
          type = "entity";
          entity = "sensor.lewis_error";
          icon = "mdi:robot-mower";
          color = "red";
          visibility = singleton {
            condition = "state";
            entity = "sensor.lewis_error";
            state_not = "no_error";
          };
        }
        {
          type = "entity";
          entity = "input_boolean.high_alert_surveillance";
          color = "red";
          name = "High Alert Enabled";
          state_content = "name";
          tap_action = {
            action = "navigate";
            navigation_path = "/lovelace/cctv";
          };
          visibility = singleton {
            condition = "state";
            entity = "input_boolean.high_alert_surveillance";
            state = "on";
          };
        }
        {
          type = "entity";
          entity = "sensor.guinea_pig_feeder";
          icon = "mdi:carrot";
          name = "Guinea Pig Feeder";
          display_type = "complete";
          color = "orange";
          visibility = singleton {
            condition = "state";
            entity = "input_boolean.guinea_pigs_fed";
            state = "off";
          };
        }
        {
          type = "entity";
          entity = "input_boolean.guinea_pigs_fed";
          name = "Guinea Pigs Not Fed";
          color = "red";
          state_content = "name";
          tap_action.action = "toggle";
          visibility = singleton {
            condition = "state";
            entity = "input_boolean.guinea_pigs_fed";
            state = "off";
          };
        }
        {
          type = "entity";
          entity = "sensor.outdoor_thermal_comfort_heat_index";
          display_type = "complete";
          name = "Heat Index";
          visibility = singleton {
            condition = "or";
            conditions = [
              {
                condition = "numeric_state";
                entity = "sensor.outdoor_thermal_comfort_heat_index";
                below = 5;
              }
              {
                condition = "numeric_state";
                entity = "sensor.outdoor_thermal_comfort_heat_index";
                above = 22;
              }
            ];
          };
        }
        {
          type = "entity";
          entity = "sensor.outdoor_thermal_comfort_frost_risk";
          display_type = "complete";
          color = "red";
          name = "Frost Risk";
          visibility = singleton {
            condition = "state";
            entity = "sensor.outdoor_thermal_comfort_frost_risk";
            state_not = "no_risk";
          };
        }
        {
          type = "entity";
          name = "Garage Door";
          entity = "sensor.garage_door_status";
          display_type = "complete";
          visibility = singleton {
            condition = "state";
            entity = "sensor.garage_door_status";
            state_not = "Closed";
          };
          tap_action = {
            action = "perform-action";
            perform_action = "script.garage_door_toggle";
          };
        }
        {
          type = "entity";
          entity = "sensor.next_bin_collection";
          color = "light-green";
          visibility = singleton {
            condition = "numeric_state";
            entity = "sensor.days_to_bin_collection";
            below = 2;
          };
          tap_action = {
            action = "navigate";
            navigation_path = "/calendar";
          };
        }
        {
          type = "entity";
          entity = "sensor.powerwall_battery_percentage";
          visibility = singleton {
            condition = "or";
            conditions = [
              {
                condition = "numeric_state";
                entity = "sensor.powerwall_battery_percentage";
                above = 95;
              }
              {
                condition = "numeric_state";
                entity = "sensor.powerwall_battery_percentage";
                below = 30;
              }
            ];
          };
        }
        {
          type = "entity";
          entity = "sensor.powerwall_site_export_power";
          display_type = "complete";
          name = "Exporting Power";
          visibility = singleton {
            condition = "state";
            entity = "binary_sensor.powerwall_grid_charge_status";
            state = "on";
          };
          color = "purple";
        }
        {
          type = "entity";
          entity = "binary_sensor.powerwall_grid_status";
          visibility = singleton {
            condition = "state";
            entity = "binary_sensor.powerwall_grid_status";
            state_not = "on";
          };
        }
        {
          type = "entity";
          entity = "binary_sensor.washing_machine_door";
          display_type = "complete";
          name = "Washing Machine Door";
          visibility = singleton {
            condition = "and";
            conditions = [
              {
                condition = "state";
                entity = "binary_sensor.washing_machine_door";
                state = "off";
              }
              {
                condition = "state";
                entity = "sensor.washing_machine_status";
                state_not = "running";
              }
            ];
          };
          color = "red";
        }
        {
          type = "entity";
          entity = "sensor.dishwasher_finish_at";
          display_type = "complete";
          name = "Dishwasher Finish";
          visibility = [
            {
              condition = "state";
              entity = "binary_sensor.dishwasher_running";
              state = "on";
            }
            {
              condition = "and";
              conditions = [
                {
                  condition = "state";
                  entity = "binary_sensor.dishwasher_running";
                  state = "on";
                }
                {
                  condition = "state";
                  entity = "sensor.dishwasher_finish_at";
                  state_not = "unknown";
                }
              ];
            }
          ];
        }
        {
          type = "entity";
          entity = "sensor.washing_machine_finish_at";
          display_type = "complete";
          name = "Washing Machine Finish";
          visibility = singleton {
            condition = "state";
            entity = "binary_sensor.washing_machine_running";
            state = "on";
          };
        }
      ]
      ++ (map (person: {
        type = "entity";
        entity = "person.${person}";
        display_type = "complete";
        visibility = singleton {
          condition = "state";
          entity = "person.${person}";
          state = "home";
        };
      }) peopleList);
    sections = [
      {
        title = "";
        type = "grid";
        cards =
          let
            navigationButton = name: card: icon: {
              inherit name icon;
              show_name = true;
              show_icon = true;
              type = "button";
              tap_action = {
                action = "navigate";
                navigation_path = "/lovelace/${card}";
              };
              layout_options = {
                grid_columns = 1;
                grid_rows = 2;
              };
            };
          in
          [
            (navigationButton "Energy" "energy" "mdi:home-lightning-bolt-outline")
            (navigationButton "CCTV" "cctv" "mdi:cctv")
            (navigationButton "Heating" "heating" "mdi:heating-coil")
            (navigationButton "HVAC" "hvac" "mdi:hvac")
            (navigationButton "Outside" "outside" "mdi:tree")
            (navigationButton "Lounge" "lounge" "mdi:sofa")
            (navigationButton "Study" "study" "mdi:chair-rolling")
            (navigationButton "Master" "master-bedroom" "mdi:bed-king")
            (navigationButton "Joshua" "joshua" "mdi:bed")
            (navigationButton upperPeople.person3 people.person3 "mdi:bed")
            (navigationButton upperPeople.person2 people.person2 "mdi:bed")
            (navigationButton upperPeople.person1 people.person1 "mdi:bed")
          ];
      }
      {
        title = "";
        type = "grid";
        cards =
          [
            {
              type = "tile";
              entity = "vacuum.roborock_s6_maxv";
              name = "Roborock";
              features = singleton {
                type = "vacuum-commands";
                commands = [
                  "start_pause"
                  "stop"
                  "clean_spot"
                ];
              };
              layout_options = {
                grid_columns = 4;
                grid_rows = 2;
              };
              visibility = singleton {
                condition = "state";
                entity = "vacuum.roborock_s6_maxv";
                state = "cleaning";
              };
            }
            {
              type = "tile";
              entity = "lawn_mower.lewis";
              features = singleton {
                type = "lawn-mower-commands";
                commands = [
                  "start_pause"
                  "dock"
                ];
              };
              layout_options = {
                grid_columns = 4;
                grid_rows = 2;
              };
              visibility = [
                {
                  condition = "state";
                  entity = "lawn_mower.lewis";
                  state_not = "docked";
                }
                {
                  condition = "state";
                  entity = "lawn_mower.lewis";
                  state_not = "unavailable";
                }
              ];
            }
          ]
          ++ (optionals frigate.enable (
            concatMap (camera: [
              {
                type = "tile";
                entity = "switch.${camera}_detect";
                visibility = singleton {
                  condition = "state";
                  entity = "switch.${camera}_detect";
                  state = "off";
                };
                layout_options = {
                  grid_columns = 4;
                  grid_rows = 1;
                };
              }
              {
                camera_view = "auto";
                entity = "image.${camera}_person";
                show_name = true;
                show_state = true;
                type = "picture-entity";
                layout_options = {
                  grid_columns = 4;
                  grid_rows = 5;
                };
                visibility = singleton {
                  condition = "state";
                  entity = "binary_sensor.${camera}_person_recently_updated";
                  state = "on";
                };
              }
            ]) cameras
          ));
      }
    ];
  };

  energy = {
    title = "Energy";
    path = "energy";
    type = "sections";
    max_columns = 3;
    subview = true;
    sections = [
      {
        type = "grid";
        cards = [ { type = "energy-distribution"; } ];
        title = "Flow";
      }
      {
        type = "grid";
        cards = [
          {
            detail = 2;
            entity = "sensor.powerwall_load_power";
            graph = "line";
            hours_to_show = 12;
            name = "House Power";
            type = "sensor";
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
          }
          {
            entities = [
              {
                entity = "binary_sensor.washing_machine_running";
                name = "Washing M";
              }
              {
                entity = "binary_sensor.dishwasher_running";
                name = "Dishwasher";
              }
            ];
            hours_to_show = 12;
            logarithmic_scale = false;
            type = "history-graph";
          }
          {
            type = "tile";
            entity = "sensor.lights_on_count";
            name = "Lights On";
            layout_options = {
              grid_columns = 2;
              grid_rows = 1;
            };
          }
          {
            type = "tile";
            entity = "sensor.electricity_maps_grid_fossil_fuel_percentage";
            icon = "mdi:barrel";
            color = "brown";
            name = "Fossil Fuel Usage";
          }
        ];
        title = "House";
      }
      {
        title = "Site";
        type = "grid";
        cards = [
          {
            detail = 2;
            entity = "sensor.powerwall_site_power";
            graph = "line";
            hours_to_show = 12;
            name = "Site Power";
            type = "sensor";
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
          }
          {
            entities = [ { entity = "binary_sensor.powerwall_grid_charge_status"; } ];
            hours_to_show = 12;
            logarithmic_scale = false;
            type = "history-graph";
          }
          {
            type = "tile";
            entity = "binary_sensor.powerwall_grid_charge_status";
            name = "Grid Charge Status";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
          {
            type = "tile";
            entity = "sensor.powerwall_backup_reserve";
            name = "Reserve Battery";
          }
          {
            type = "tile";
            entity = "switch.powerwall_off_grid_operation";
            name = "Go Off-grid";
            color = "red";
            hide_state = true;
            vertical = false;
          }
        ];
      }
      {
        title = "Solar";
        type = "grid";
        cards = singleton {
          detail = 2;
          entity = "sensor.powerwall_solar_power";
          graph = "line";
          hours_to_show = 12;
          name = "Solar Power";
          type = "sensor";
          layout_options = {
            grid_columns = 4;
            grid_rows = 2;
          };
        };
      }
      {
        title = "Battery";
        type = "grid";
        cards = [
          {
            graph = "line";
            detail = 2;
            entity = "sensor.powerwall_battery_percentage";
            hours_to_show = 12;
            name = "Battery Charge";
            type = "sensor";
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
          }
          {
            detail = 2;
            entity = "sensor.powerwall_battery_power";
            graph = "line";
            hours_to_show = 12;
            name = "Battery Power";
            type = "sensor";
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
          }
          {
            entities = [ { entity = "binary_sensor.powerwall_battery_charge_status"; } ];
            hours_to_show = 12;
            type = "history-graph";
          }
          {
            type = "tile";
            entity = "binary_sensor.powerwall_battery_charge_status";
            name = "Battery Charge Status";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
          {
            type = "tile";
            entity = "sensor.powerwall_battery_remaining_time";
            name = "Battery Time";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
        ];
      }
      {
        title = "Finances";
        type = "grid";
        cards = [
          {
            type = "tile";
            entity = "sensor.grid_buy_price";
            name = "Import Cost";
            icon = "mdi:cash";
          }
          {
            type = "tile";
            entity = "sensor.grid_sell_price";
            name = "Export Cost";
            icon = "mdi:cash";
          }
          {
            chart_type = "line";
            entities = [
              {
                entity = "sensor.powerwall_site_import_cost";
                name = "Month Import Cost";
              }
              {
                entity = "sensor.powerwall_site_export_compensation";
                name = "Month Export Compensation";
              }
            ];
            period = "hour";
            stat_types = [ "sum" ];
            type = "statistics-graph";
          }
          {
            chart_type = "line";
            entities = singleton {
              entity = "sensor.powerwall_aggregate_cost";
              name = "Month Aggregate Cost";
            };
            period = "hour";
            stat_types = [ "sum" ];
            type = "statistics-graph";
          }
        ];
      }
    ];
  };

  outside = {
    title = "Outside";
    path = "outside";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections = [
      {
        title = "Weather";
        type = "grid";
        cards = [
          {
            entity = "weather.forecast_home";
            forecast_type = "hourly";
            type = "weather-forecast";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.outdoor_sensor_temperature";
            detail = 2;
            name = "Temperature";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.outdoor_sensor_humidity";
            detail = 2;
            name = "Humidity";
          }
        ];
      }
      {
        title = "Garage";
        type = "grid";
        cards = [
          {
            name = "Garage Door Toggle";
            type = "tile";
            entity = "sensor.garage_door_status";
            tap_action = {
              action = "perform-action";
              perform_action = "script.garage_door_toggle";
            };
            icon_tap_action = {
              action = "perform-action";
              perform_action = "script.garage_door_toggle";
            };
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
          {
            type = "history-graph";
            entities = singleton {
              name = "Garage";
              entity = "binary_sensor.garage_door_closed";
            };
            hours_to_show = 6;
          }
        ];
      }
      {
        title = "Automower";
        type = "grid";
        cards = [
          {
            type = "tile";
            entity = "lawn_mower.lewis";
            features = singleton {
              type = "lawn-mower-commands";
              commands = [
                "start_pause"
                "dock"
              ];
            };
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
          }
          {
            type = "tile";
            name = "Scheduled Mowing";
            entity = "switch.lewis_enable_schedule";
          }
          {
            type = "tile";
            name = "Next Start Time";
            entity = "sensor.lewis_next_start";
          }
        ];
      }
      {
        title = "Bin Collections";
        type = "grid";
        cards = singleton {
          type = "calendar";
          initial_view = "listWeek";
          entities = [ "calendar.bin_collection_schedule" ];
        };
      }
    ];
  };
in
{
  services.home-assistant.lovelaceConfig = {
    title = "Dashboard";

    views =
      [
        home
        cfg.homeAnnouncements.lovelaceView
        cfg.guineaPigs.lovelaceView
        energy
        outside
      ]
      ++ mapAttrsToList (_: roomCfg: roomCfg.lovelace.dashboard) (
        filterAttrs (_: v: v.lovelace.enable) cfg.rooms
      );
  };
}
