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
    ;
  inherit (config.modules.services) frigate;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (secrets.lovelace) heating;
  inherit (secrets.general) people userIds;

  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
  cameras = attrNames config.services.frigate.settings.cameras;
  upperPeople = mapAttrs (_: p: utils.upperFirstChar p) people;

  allLightingTile = room: {
    type = "tile";
    entity = "light.${room}";
    name = "All Lighting";
    layout_options = {
      grid_columns = 4;
      grid_rows = 1;
    };
    features = [
      { type = "light-brightness"; }
      { type = "light-color-temp"; }
    ];
  };

  lightTile = entity: {
    type = "tile";
    entity = "light.${entity}";
    visibility = singleton {
      condition = "state";
      entity = "light.${entity}";
      state_not = "unavailable";
    };
  };

  adaptiveLightingTiles = room: [
    {
      type = "tile";
      entity = "switch.adaptive_lighting_${room}";
      layout_options = {
        grid_columns = 4;
        grid_rows = 1;
      };
      name = "Adaptive Lighting";
    }
    {
      type = "tile";
      entity = "switch.adaptive_lighting_adapt_brightness_${room}";
      name = "Adapt Brightness";
      visibility = singleton {
        condition = "state";
        entity = "switch.adaptive_lighting_${room}";
        state = "on";
      };
    }
    {
      type = "tile";
      entity = "switch.adaptive_lighting_adapt_color_${room}";
      name = "Adapt Colour";
      visibility = singleton {
        condition = "state";
        entity = "switch.adaptive_lighting_${room}";
        state = "on";
      };
    }
  ];

  home = {
    title = "Home";
    path = "home";
    type = "sections";
    sections = [
      {
        title = "Views";
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
            (navigationButton "Lounge" "lounge" "mdi:sofa")
            (navigationButton "Joshua" "joshua-room" "mdi:bed")
            (navigationButton "${upperPeople.person1}" "${people.person1}-room" "mdi:bed")
            (navigationButton "${upperPeople.person2}" "${people.person2}-room" "mdi:bed")
            (navigationButton "${upperPeople.person3}" "${people.person3}-room" "mdi:bed")
          ];
      }
      {
        title = "Dynamic";
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
            map (camera: {
              type = "tile";
              entity = "binary_sensor.${camera}_person_occupancy";
              name = "${utils.upperFirstChar camera} Person Occupancy";
              visibility = singleton {
                condition = "state";
                entity = "binary_sensor.${camera}_person_occupancy";
                state = "on";
              };
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }) cameras
          ))
          ++ [
            {
              type = "tile";
              entity = "sensor.next_bin_collection";
              color = "light-green";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
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
              type = "tile";
              entity = "binary_sensor.powerwall_grid_status";
              visibility = singleton {
                condition = "state";
                entity = "binary_sensor.powerwall_grid_status";
                state_not = "on";
              };
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }
            {
              type = "tile";
              entity = "sensor.powerwall_battery_percentage";
              name = "Powerwall Charge";
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
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }
            {
              type = "tile";
              entity = "binary_sensor.powerwall_grid_charge_status";
              name = "Currently Exporting Excess Power";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
              visibility = singleton {
                condition = "state";
                entity = "binary_sensor.powerwall_grid_charge_status";
                state = "on";
              };
              color = "purple";
              hide_state = true;
            }
            {
              type = "tile";
              entity = "binary_sensor.washing_machine_door";
              name = "Washing Machine Door";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
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
              type = "tile";
              entity = "sensor.dishwasher_finish_at";
              name = "Dishwasher Finish Time";
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
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }
            {
              type = "tile";
              entity = "sensor.washing_machine_finish_at";
              name = "Washing Machine Finish Time";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
              visibility = singleton {
                condition = "state";
                entity = "binary_sensor.washing_machine_running";
                state = "on";
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
          ));
      }
      {
        title = "Weather";
        type = "grid";
        cards = [
          {
            entity = "weather.forecast_home";
            forecast_type = "daily";
            type = "weather-forecast";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.outdoor_temperature";
            detail = 2;
            name = "Temperature";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.outdoor_humidity";
            detail = 2;
            name = "Humidity";
          }
          {
            type = "tile";
            entity = "sensor.outdoor_thermal_comfort_heat_index";
            name = "Heat Index";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
          {
            type = "tile";
            entity = "sensor.outdoor_thermal_comfort_frost_risk";
            color = "red";
            name = "Frost Risk";
            visibility = singleton {
              condition = "state";
              entity = "sensor.outdoor_thermal_comfort_frost_risk";
              state_not = "no_risk";
            };
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
          }
        ];
      }
    ];
    max_columns = 3;
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
    sections = [
      {
        type = "grid";
        cards = [
          (allLightingTile "lounge")
          {
            camera_image = "camera.lounge_floorplan";
            type = "picture-elements";
            elements =
              let
                lightElem = number: left: top: {
                  entity = "light.lounge_spot_ceiling_${number}";
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
                (lightElem "01" 85 65)
                (lightElem "02" 85 25)
                (lightElem "03" 72 45)
                (lightElem "04" 59 65)
                (lightElem "05" 59 25)
                (lightElem "06" 39 65)
                (lightElem "07" 39 25)
                (lightElem "08" 26 45)
                (lightElem "09" 13 65)
                (lightElem "10" 13 25)
              ];
          }
        ];
        title = "Lighting";
        visibility = singleton {
          condition = "state";
          entity = "light.lounge_spot_ceiling_01";
          state_not = "unavailable";
        };
      }
      {
        title = "Heating";
        type = "grid";
        cards = [
          {
            type = "thermostat";
            entity = "climate.lounge";
            features = [ { type = "climate-hvac-modes"; } ];
          }
          {
            type = "history-graph";
            entities = [ { entity = "climate.lounge"; } ];
            hours_to_show = 6;
          }
        ];
      }
      {
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
      }
    ];
  };

  joshuaRoom = {
    title = "Joshua's Room";
    path = "joshua-room";
    type = "sections";
    max_columns = 2;
    subview = true;
    sections = [
      {
        title = "Lighting";
        type = "grid";
        cards =
          [
            (allLightingTile "joshua_room")
            (lightTile "joshua_lamp_floor_01")
            (lightTile "joshua_strip_bed_01")
            (lightTile "joshua_lamp_bed_01")
            (lightTile "joshua_bulb_ceiling_01")
            (lightTile "joshua_play_desk_01")
            (lightTile "joshua_play_desk_02")
          ]
          ++ (adaptiveLightingTiles "joshua_room")
          ++ (singleton {
            type = "tile";
            entity = "input_boolean.joshua_room_wake_up_lights";
            layout_options = {
              grid_columns = 4;
              grid_rows = 1;
            };
            name = "Wake Up Lights";
          });
      }
      {
        type = "grid";
        title = "Climate";
        cards = [
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.joshua_temperature";
            detail = 2;
            layout_options = {
              grid_columns = 4;
              grid_rows = 3;
            };
            name = "Temperature";
          }
          {
            graph = "line";
            type = "sensor";
            entity = "sensor.joshua_humidity";
            detail = 2;
            layout_options = {
              grid_columns = 4;
              grid_rows = 3;
            };
            name = "Humidity";
          }
          {
            type = "tile";
            entity = "sensor.joshua_thermal_comfort_summer_scharlau_perception";
            name = "Summer Scharlau";
          }
          {
            type = "tile";
            entity = "sensor.joshua_thermal_comfort_thoms_discomfort_perception";
            name = "Thoms Discomfort";
          }
        ];
      }
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
          cards =
            [
              (allLightingTile "${person}_room")
              (lightTile "${person}_lamp_desk_01")
            ]
            ++ (adaptiveLightingTiles "${person}_room")
            ++ [
              {
                type = "tile";
                entity = "input_boolean.${person}_room_wake_up_lights";
                name = "Wake Up Lights";
                layout_options = {
                  grid_columns = 4;
                  grid_rows = 1;
                };
              }
              {
                type = "tile";
                entity = "input_datetime.${person}_wake_up_time";
                name = "Wake Up Time";
                visibility = singleton {
                  condition = "state";
                  entity = "input_boolean.${person}_room_wake_up_lights";
                  state = "on";
                };
              }
              {
                type = "tile";
                entity = "input_datetime.${person}_sleep_time";
                name = "Sleep Time";
                visibility = singleton {
                  condition = "state";
                  entity = "input_boolean.${person}_room_wake_up_lights";
                  state = "on";
                };
              }
            ];
        }
        {
          type = "grid";
          cards = [
            {
              type = "thermostat";
              entity = "climate.${person}_room";
              features = [ { type = "climate-hvac-modes"; } ];
              show_current_as_primary = false;
            }
            {
              type = "history-graph";
              show_names = true;
              entities = [ { entity = "climate.${person}_room"; } ];
              hours_to_show = 6;
            }
          ];
          title = "Heating";
        }
      ];
      cards = [ ];
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
      sections = singleton {
        title = "Lighting";
        type = "grid";
        cards = [
          (allLightingTile "${person}_room")
          (lightTile "${person}_spot_ceiling_01")
          (lightTile "${person}_spot_ceiling_02")
          (lightTile "${person}_spot_ceiling_03")
          (lightTile "${person}_play_desk_01")
          (lightTile "${person}_play_desk_02")
          (lightTile "${person}_strip_desk_01")
        ];
      };
      cards = [ ];
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
      sections = singleton {
        title = "Lighting";
        type = "grid";
        cards = [
          (allLightingTile "${person}_room")
          (lightTile "${person}_spot_ceiling_01")
          (lightTile "${person}_spot_ceiling_02")
          (lightTile "${person}_spot_ceiling_03")
          (lightTile "${person}_play_shelf_01")
          (lightTile "${person}_play_shelf_02")
          (lightTile "${person}_strip_desk_01")
        ];
      };
      cards = [ ];
    };

in
mkIf cfg.enableInternal {
  services.home-assistant = {
    lovelaceConfig = {
      title = "Dashboard";

      views =
        [
          home
          energy
        ]
        ++ optional frigate.enable cctv
        ++ [
          heating
          lounge
          joshuaRoom
          room1
          room2
          room3
        ];
    };
  };
}
