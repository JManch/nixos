{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkAfter
    concatMap
    attrValues
    mkOption
    optional
    mkEnableOption
    singleton
    ;
  cfg = config.${ns}.services.hass;
in
{
  options.${ns}.services.hass.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        let
          inherit (config.climate)
            temperature
            humidity
            underfloorHeating
            airConditioning
            ;
        in
        {
          options.climate = {
            temperature = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "joshua_sensor_temperature";
              description = "Entity ID of numeric temperature sensor in the room";
            };

            humidity = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "joshua_sensor_humidity";
              description = "Entity ID of numeric humidity sensor in the room";
            };

            underfloorHeating = {
              enable = mkEnableOption "underfloor heating integration";
              id = mkOption {
                type = types.str;
                description = "Entity ID of the climate sensor";
                example = "joshua_underfloor_heating";
              };
            };

            airConditioning = {
              enable = mkEnableOption "air conditioning integration";
              id = mkOption {
                type = types.str;
                description = "Entity ID of the climate sensor";
                example = "joshua_ac_room_temperature";
              };
            };
          };

          config.lovelace.sections =
            let
              cards =
                let
                  thermostat = isHeating: small: {
                    name = if small then (if isHeating then "Underfloor Heating" else "Air Conditioning") else " ";
                    type = "thermostat";
                    entity = "climate.${if isHeating then underfloorHeating.id else airConditioning.id}";
                    features = singleton { type = "climate-hvac-modes"; };
                    grid_options.columns = if small then 6 else 12;
                    grid_options.rows = if small then 5 else 6;
                  };
                in
                (
                  if (airConditioning.enable && underfloorHeating.enable) then
                    [
                      (thermostat true true)
                      (thermostat false true)
                    ]
                  else if airConditioning.enable then
                    singleton (thermostat false false)
                  else if underfloorHeating.enable then
                    singleton (thermostat true false)
                  else
                    [ ]
                )
                ++ optional (temperature != null) {
                  name = "Temperature";
                  type = "sensor";
                  graph = "line";
                  entity = "sensor.${temperature}";
                  detail = 2;
                  grid_options = mkIf (humidity == null) {
                    columns = 12;
                    rows = 2;
                  };
                }
                ++ optional (humidity != null) {
                  name = "Humidity";
                  type = "sensor";
                  graph = "line";
                  entity = "sensor.${humidity}";
                  detail = 2;
                  grid_options = mkIf (temperature == null) {
                    columns = 12;
                    rows = 2;
                  };
                };
            in
            optional (cards != [ ]) {
              title = "Climate";
              priority = 2;
              type = "grid";
              inherit cards;
            };
        }
      )
    );
  };

  config.services.home-assistant = {
    lovelaceConfig.views = mkAfter [
      {
        title = "Heating";
        path = "heating";
        type = "sections";
        max_columns = 2;
        subview = true;
        sections = [
          {
            title = "Central Heating";
            type = "grid";
            cards = [
              {
                name = "Hallway";
                type = "thermostat";
                entity = "climate.central_heating";
                features = singleton { type = "climate-hvac-modes"; };
              }
              {
                name = "Automatically Toggle";
                type = "tile";
                entity = "input_boolean.central_heating_enabled";
                grid_options.columns = 12;
                grid_options.rows = 1;
              }
              {
                name = "Enable Time";
                type = "tile";
                entity = "input_datetime.central_heating_enable_time";
              }
              {
                name = "Disable Time";
                type = "tile";
                entity = "input_datetime.central_heating_disable_time";
              }
              {
                name = "Temperature";
                type = "sensor";
                graph = "line";
                entity = "sensor.central_heating_current_temperature";
                detail = 2;
                grid_options.columns = 12;
                grid_options.rows = 2;
              }
            ];
          }
          {
            title = "Underfloor Heating";
            type = "grid";
            cards = concatMap (
              roomCfg:
              let
                inherit (roomCfg) formattedRoomName;
                inherit (roomCfg.climate) underfloorHeating;
              in
              optional underfloorHeating.enable {
                name = formattedRoomName;
                type = "thermostat";
                entity = "climate.${underfloorHeating.id}";
                features = singleton { type = "climate-hvac-modes"; };
                grid_options.columns = 6;
                grid_options.rows = 5;
              }
            ) (attrValues cfg.rooms);
          }
        ];
      }
      {
        title = "HVAC";
        path = "hvac";
        type = "sections";
        max_columns = 2;
        subview = true;
        sections = [
          {
            title = "Rooms";
            type = "grid";
            cards = concatMap (
              roomCfg:
              let
                inherit (roomCfg) formattedRoomName;
                inherit (roomCfg.climate) airConditioning;
              in
              optional airConditioning.enable {
                name = formattedRoomName;
                type = "thermostat";
                entity = "climate.${airConditioning.id}";
                features = singleton { type = "climate-hvac-modes"; };
                grid_options.columns = 6;
                grid_options.rows = 5;
              }
            ) (attrValues cfg.rooms);
          }
        ];
      }
    ];

    config = {
      automation = singleton {
        alias = "Central Heating Toggle";
        mode = "single";
        triggers = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time";
            at = "input_datetime.central_heating_enable_time";
          }
          {
            platform = "time";
            at = "input_datetime.central_heating_disable_time";
          }
        ];
        actions = singleton {
          "if" = singleton {
            condition = "and";
            conditions = [
              {
                condition = "time";
                after = "input_datetime.central_heating_enable_time";
                before = "input_datetime.central_heating_disable_time";
              }
              {
                condition = "state";
                entity_id = "input_boolean.central_heating_enabled";
                state = "on";
              }
            ];
          };
          "then" = singleton {
            action = "climate.turn_on";
            target.entity_id = "climate.central_heating";
          };
          "else" = singleton {
            action = "climate.turn_off";
            target.entity_id = "climate.central_heating";
          };
        };
      };

      input_datetime = {
        central_heating_enable_time = {
          name = "Central Heating Enable Time";
          has_time = true;
        };

        central_heating_disable_time = {
          name = "Central Heating Disable Time";
          has_time = true;
        };
      };

      input_boolean.central_heating_enabled = {
        name = "Central Heating Enabled";
        icon = "mdi:heating-coil";
      };
    };
  };
}
