{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    optional
    optionals
    singleton
    attrNames
    mapAttrs
    concatMap
    splitString
    concatMapStringsSep
    ;
  inherit (config.modules.services) frigate;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (secrets.lovelace) heating hvac;
  inherit (secrets.general) people userIds peopleList;
  inherit (config.modules.services.hass) smartLightingRooms;

  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
  cameras = attrNames config.services.frigate.settings.cameras;
  upperPeople = mapAttrs (_: p: utils.upperFirstChar p) people;

  floorPlanLight = light: left: top: {
    entity = "light.${light}";
    style = {
      background = "rgba(0, 0, 0, 0.8)";
      border-radius = "50%";
      left = "${toString left}%";
      top = "${toString top}%";
    };
    tap_action.action = "toggle";
    type = "state-icon";
  };

  basicLightsCards = room: [
    {
      type = "button";
      name = "Toggle";
      entity = "light.${room}_lights";
      tap_action.action = "toggle";
      layout_options = {
        grid_columns = 1;
        grid_rows = if room != "study" then 3 else 2;
      };
    }
    {
      type = "tile";
      entity = "light.${room}_lights";
      name = "All Lights";
      layout_options = {
        grid_columns = 3;
        grid_rows = if room != "study" then 3 else 2;
      };
      features = [
        { type = "light-brightness"; }
      ] ++ (optional (room != "study") { type = "light-color-temp"; });
    }
  ];

  acSection =
    sensor:
    singleton {
      title = "Air Conditioning";
      type = "grid";
      cards = [
        {
          name = " ";
          type = "thermostat";
          entity =
            if sensor != "joshua" then
              "climate.${sensor}_ac_room_temperature"
            else
              "climate.joshua_faikin_mqtt_hvac";
          features = singleton { type = "climate-hvac-modes"; };
        }
        {
          name = "Temperature";
          type = "sensor";
          graph = "line";
          entity =
            if sensor == "joshua" then
              "sensor.joshua_sensor_temperature"
            else
              "sensor.${sensor}_ac_climatecontrol_room_temperature";
          detail = 2;
        }
        {
          name = "Humidity";
          type = "sensor";
          graph = "line";
          entity =
            if sensor == "joshua" then
              "sensor.joshua_sensor_humidity"
            else
              "sensor.${sensor}_ac_climatecontrol_room_humidity";
          detail = 2;
        }
      ];
    };

  underfloorHeatingSection =
    sensor:
    singleton {
      title = "Underfloor Heating";
      type = "grid";
      cards = [
        {
          name = " ";
          type = "thermostat";
          entity = "climate.${sensor}_underfloor_heating";
          features = singleton { type = "climate-hvac-modes"; };
        }
        {
          type = "history-graph";
          show_names = true;
          entities = [ { entity = "climate.${sensor}_underfloor_heating"; } ];
        }
      ];
    };

  home = {
    title = "Home";
    path = "home";
    type = "sections";
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
          entity = "sensor.lewis_mode";
          icon = "mdi:robot-mower";
          color = "green";
          visibility = singleton {
            condition = "state";
            entity = "sensor.lewis_mode";
            state_not = "home";
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
          entity = "input_boolean.guinea_pigs_fed";
          name = "Guinea Pigs Fed";
          color = "green";
          state_content = "name";
          tap_action.action = "toggle";
          visibility = singleton {
            condition = "state";
            entity = "input_boolean.guinea_pigs_fed";
            state = "on";
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
          state = "not_home";
        };
      }) peopleList)
      ++ (map (data: {
        type = "entity";
        display_type = "complete";
        entity = "light.${data.light}";
        name =
          concatMapStringsSep " " (string: utils.upperFirstChar string) (splitString "_" data.room)
          + " Ceiling Lights";
        icon = "mdi:lightbulb-alert";
        visibility = singleton {
          condition = "state";
          entity = "light.${data.light}";
          state = "unavailable";
        };
      }) cfg.ceilingLightRooms);
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

            blankButton = {
              name = "";
              icon = "";
              type = "button";
              tap_action.action = "none";
              hold_action.action = "none";
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
            (navigationButton "Joshua" "joshua-room" "mdi:bed")
            (navigationButton "${upperPeople.person3}" "${people.person3}-room" "mdi:bed")
            (navigationButton "${upperPeople.person2}" "${people.person2}-room" "mdi:bed")
            (navigationButton "${upperPeople.person1}" "${people.person1}-room" "mdi:bed")
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
              visibility = singleton {
                condition = "state";
                entity = "lawn_mower.lewis";
                state_not = "docked";
              };
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
          ))
          ++ singleton {
            type = "custom:formulaone-card";
            card_type = "countdown";
            f1_font = true;
            show_raceinfo = true;
            countdown_type = [
              "race"
              "qualifying"
              "sprint"
            ];
            visibility = [
              {
                condition = "numeric_state";
                entity = "sensor.days_to_formula_1_event";
                below = 2;
              }
              {
                condition = "user";
                users = [
                  userIds.joshua
                  userIds.${people.person1}
                  userIds.${people.person3}
                  userIds.${people.person5}
                ];
              }
            ];
          };
      }
    ];
    max_columns = 2;
    cards = [ ];
  };

  energy = {
    title = "Energy";
    path = "energy";
    type = "sections";
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
    max_columns = 3;
    cards = [ ];
    subview = true;
  };

  cctv = {
    title = "CCTV";
    path = "cctv";
    type = "sections";
    max_columns = 2;
    sections = [
      {
        title = "Live Views";
        type = "grid";
        cards = map (camera: {
          cameras = singleton {
            camera_entity = "camera.${camera}";
            frigate.url = "https://cctv.${fqDomain}";
            live_provider = "go2rtc";
            go2rtc.modes = [ (if frigate.webrtc.enable then "webrtc" else "mse") ];
          };
          live = {
            show_image_during_load = true;
            transition_effect = "none";
          };
          menu = {
            style = "hover-card";
            buttons = {
              cameras.enabled = false;
              expand.enabled = false;
              fullscreen.enabled = true;
              timeline.enabled = true;
            };
          };
          performance.profile = "low";
          type = "custom:frigate-card";
        }) cameras;
      }
      {
        title = "Last Seen";
        type = "grid";
        cards = map (camera: {
          show_state = true;
          show_name = false;
          camera_view = "auto";
          entity = "image.${camera}_person";
          type = "picture-entity";
          layout_options = {
            grid_columns = 2;
            grid_rows = "auto";
          };
        }) cameras;
      }
      {
        title = "Settings";
        type = "grid";
        cards =
          (singleton {
            type = "tile";
            entity = "input_boolean.high_alert_surveillance";
            name = "High Alert Mode";
            color = "red";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          })
          ++ map (camera: {
            type = "tile";
            entity = "switch.${camera}_detect";
          }) cameras;
      }
      {
        title = "Debug";
        type = "grid";
        cards = map (camera: {
          type = "tile";
          entity = "binary_sensor.${camera}_motion";
        }) cameras;
        visibility = singleton {
          condition = "user";
          users = [ userIds.joshua ];
        };
      }
    ];
    cards = [ ];
    subview = true;
  };

  lounge = {
    title = "Lounge";
    path = "lounge";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections =
      singleton {
        title = "Lighting";
        type = "grid";
        visibility = singleton {
          condition = "state";
          entity = "light.lounge_spot_ceiling_1";
          state_not = "unavailable";
        };
        cards = smartLightingRooms.lounge.lovelaceCards {
          floorPlanLights = [
            (floorPlanLight "lounge_spot_ceiling_1" 85 65)
            (floorPlanLight "lounge_spot_ceiling_2" 85 25)
            (floorPlanLight "lounge_spot_ceiling_3" 72 45)
            (floorPlanLight "lounge_spot_ceiling_4" 59 65)
            (floorPlanLight "lounge_spot_ceiling_5" 59 25)
            (floorPlanLight "lounge_spot_ceiling_6" 39 65)
            (floorPlanLight "lounge_spot_ceiling_7" 39 25)
            (floorPlanLight "lounge_spot_ceiling_8" 26 45)
            (floorPlanLight "lounge_spot_ceiling_9" 13 65)
            (floorPlanLight "lounge_spot_ceiling_10" 13 25)
          ];
        };
      }
      ++ (underfloorHeatingSection "lounge")
      ++ singleton {
        title = "Devices";
        type = "grid";
        cards = [
          {
            type = "tile";
            entity = "vacuum.roborock_s6_maxv";
            layout_options = {
              grid_columns = 4;
              grid_rows = 2;
            };
            features = singleton {
              type = "vacuum-commands";
              commands = [
                "start_pause"
                "stop"
                "clean_spot"
              ];
            };
          }
          {
            type = "media-control";
            entity = "media_player.lounge_tv";
          }
        ];
      };
  };

  study = {
    title = "Study";
    path = "study";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections = [
      {
        title = "Lighting";
        type = "grid";
        cards =
          (basicLightsCards "study")
          ++ singleton {
            camera_image = "camera.study_floorplan";
            type = "picture-elements";
            elements =
              let
                lightElem = number: left: top: {
                  entity = "light.study_spot_ceiling_${toString number}";
                  style = {
                    background = "rgba(0, 0, 0, 0.8)";
                    border-radius = "50%";
                    left = "${toString left}%";
                    top = "${toString top}%";
                  };
                  tap_action.action = "toggle";
                  type = "state-icon";
                };
              in
              [
                (lightElem 1 78 52)
                (lightElem 2 48 52)
                (lightElem 3 48 20)
                (lightElem 4 25 70)
                (lightElem 5 25 40)
              ];
          };
        visibility = singleton {
          condition = "state";
          entity = "light.study_spot_ceiling_1";
          state_not = "unavailable";
        };
      }
    ] ++ (acSection "study");
  };

  joshuaRoom = {
    title = "Joshua's Room";
    path = "joshua-room";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections =
      singleton {
        title = "Lighting";
        type = "grid";
        cards = smartLightingRooms.joshuaRoom.lovelaceCards {
          individualLights = [
            "joshua_lamp_floor"
            "joshua_lamp_bed"
            "joshua_bulb_ceiling"
            "joshua_play_desk_1"
            "joshua_play_desk_2"
          ];
        };
      }
      ++ acSection "joshua"
      ++ [
        {
          title = "Dehumidifier";
          type = "grid";
          cards = [
            {
              type = "tile";
              entity = "input_boolean.joshua_dehumidifier_automatic_control";
              name = "Automatic Control";
              layout_options = {
                grid_columns = 2;
                grid_rows = 1;
              };
            }
            {
              type = "tile";
              entity = "switch.joshua_dehumidifier";
              name = "Running";
            }
            {
              type = "tile";
              entity = "sensor.joshua_dehumidifier_tank_status";
              name = "Tank Status";
              visibility = singleton {
                condition = "state";
                entity = "sensor.joshua_dehumidifier_tank_status";
                state = "Full";
              };
              color = "red";
              icon = "";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }
            {
              type = "tile";
              entity = "sensor.joshua_mold_indicator";
              name = "Mold Indicator";
              icon = "mdi:molecule";
            }
            {
              type = "tile";
              entity = "sensor.joshua_critical_temperature";
              name = "Critical Temperature";
            }
          ];
        }
        {
          type = "grid";
          cards = singleton {
            type = "history-graph";
            entities = [ { entity = "binary_sensor.ncase_m1_active"; } ];
            hours_to_show = 24;
          };
          title = "Devices";
          visibility = singleton {
            condition = "user";
            users = [ userIds.joshua ];
          };
        }
      ];
  };

  room1 =
    let
      person = people.person1;
    in
    {
      title = "${upperPeople.person1}'s Room";
      path = "${person}-room";
      type = "sections";
      max_columns = 2;
      subview = true;
      sections = [
        {
          title = "Lighting";
          type = "grid";
          cards = smartLightingRooms."${person}Room".lovelaceCards { };
        }
      ] ++ (acSection person) ++ (underfloorHeatingSection person);
    };

  room2 =
    let
      person = people.person2;
    in
    {
      title = "${upperPeople.person2}'s Room";
      path = "${person}-room";
      type = "sections";
      max_columns = 2;
      subview = true;
      sections =
        singleton {
          title = "Lighting";
          type = "grid";
          cards = smartLightingRooms."${person}Room".lovelaceCards {
            individualLights = [
              "${person}_spot_ceiling_1"
              "${person}_spot_ceiling_2"
              "${person}_spot_ceiling_3"
              "${person}_play_desk_1"
              "${person}_play_desk_2"
              "${person}_strip_bed"
            ];
          };
        }
        ++ (acSection person);
    };

  room3 =
    let
      person = people.person3;
    in
    {
      title = "${upperPeople.person3}'s Room";
      path = "${person}-room";
      type = "sections";
      max_columns = 2;
      subview = true;
      sections =
        singleton {
          title = "Lighting";
          type = "grid";
          cards = smartLightingRooms."${person}Room".lovelaceCards {
            floorPlanLights = [
              (floorPlanLight "${person}_spot_ceiling_1" 75 75)
              (floorPlanLight "${person}_spot_ceiling_2" 75 25)
              (floorPlanLight "${person}_spot_ceiling_3" 50 50)
              (floorPlanLight "${person}_spot_ceiling_4" 25 75)
              (floorPlanLight "${person}_spot_ceiling_5" 25 25)
            ];
          };
        }
        ++ (acSection person);
    };

  master = {
    title = "Master Bedroom";
    path = "master-bedroom";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections = acSection "master";
  };

  outside = {
    title = "Outside";
    path = "outside";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections = [
      {
        title = "";
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
        title = "";
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
    ];
  };
in
mkIf cfg.enableInternal {
  services.home-assistant = {
    lovelaceConfig = {
      title = "Dashboard";

      views =
        [
          home
          cfg.homeAnnouncements.lovelaceView
          cfg.guineaPigs.lovelaceView
          energy
        ]
        ++ optional frigate.enable cctv
        ++ [
          heating
          hvac
          outside
          lounge
          study
          master
          joshuaRoom
          room1
          room2
          room3
        ];
    };
  };
}
