{ lib, cfg }:
let
  inherit (lib)
    mkIf
    mkMerge
    types
    mkOption
    mkEnableOption
    optional
    splitString
    elemAt
    toSentenceCase
    mapAttrsToList
    singleton
    ;
in
{
  opts.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        let
          inherit (config) blinds;
          blindName = id: toSentenceCase (elemAt (splitString "_" id) 2);
        in
        {
          options.blinds = {
            entities = mkOption {
              type = with types; listOf str;
              default = [ ];
              example = [ "joshua_blind_garden" ];
              description = "List of entity IDs of blind 'cover' entities";
            };

            automatedClose = {
              enable = mkEnableOption ''
                automatically closing the blinds when the sun is below the set elevation threshold.
              '';

              elevationThreshold = mkOption {
                type = types.int;
                default = -2;
                description = ''
                  Sun elevation below which the blinds will automatically close.
                '';
              };
            };
          };

          config.lovelace.sections = optional (blinds.entities != [ ]) {
            title = "Blinds";
            type = "grid";
            priority = 2;
            cards = [
              {
                type = "tile";
                name = "All Blinds";
                entity = "cover.${name}_blinds";
                features = singleton {
                  type = "cover-open-close";
                };
                grid_options = {
                  columns = "full";
                  rows = "auto";
                };
              }
            ]
            ++ optional blinds.automatedClose.enable {
              name = "Automated Close";
              type = "tile";
              entity = "input_boolean.${name}_automated_blinds_close";
              layout_options = {
                grid_columns = 4;
                grid_rows = 1;
              };
            }
            ++ map (id: {
              type = "tile";
              name = blindName id;
              entity = "cover.${id}";
              grid_options.rows = "auto";
            }) blinds.entities;
          };
        }
      )
    );
  };

  services.home-assistant.config = mkMerge (
    mapAttrsToList (
      room: roomCfg:
      let
        inherit (roomCfg) blinds formattedRoomName;
      in
      mkIf (blinds.entities != [ ]) {
        cover = singleton {
          platform = "group";
          name = "${formattedRoomName} Blinds";
          entities = map (blind: "cover.${blind}") blinds.entities;
        };

        input_boolean."${room}_automated_blinds_close" = mkIf (blinds.automatedClose.enable) {
          name = "${formattedRoomName} Automated Blinds Close";
          icon = "mdi:blinds";
        };

        automation =
          optional blinds.automatedClose.enable {
            alias = "${formattedRoomName} Close Blinds";
            mode = "single";
            triggers = [
              {
                trigger = "state";
                entity_id = "light.${room}_lights";
                to = "on";
              }
              {
                trigger = "numeric_state";
                entity_id = "sun.sun";
                attribute = "elevation";
                below = roomCfg.blinds.automatedClose.elevationThreshold;
              }
            ];

            conditions = [
              {
                condition = "state";
                entity_id = "input_boolean.${room}_automated_blinds_close";
                state = "on";
              }
              {
                condition = "numeric_state";
                entity_id = "sun.sun";
                attribute = "elevation";
                below = roomCfg.blinds.automatedClose.elevationThreshold;
              }
              {
                condition = "state";
                entity_id = "light.${room}_lights";
                state = "on";
              }
              {
                condition = "not";
                conditions = singleton {
                  condition = "state";
                  entity_id = "cover.${room}_blinds";
                  state = "closed";
                };
              }
            ];

            actions = singleton {
              action = "cover.close_cover";
              target.entity_id = "cover.${room}_blinds";
            };
          }
          ++ optional (roomCfg.lighting.wallSwitch.topic != null) {
            alias = "${formattedRoomName} Toggle Blinds Switch";
            mode = "single";

            triggers = singleton {
              trigger = "event";
              event_type = "${room}_wall_switch_flick";
              event_data.flicks = 2;
            };

            actions = singleton {
              action = "cover.toggle";
              target.entity_id = "cover.${room}_blinds";
            };
          };
      }
    ) cfg.rooms
  );
}
