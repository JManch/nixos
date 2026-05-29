{ lib, cfg }:
let
  inherit (lib)
    mkIf
    mkMerge
    types
    mkOption
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
          options = {
            blinds = mkOption {
              type = with types; listOf str;
              default = [ ];
              example = [ "joshua_blind_garden" ];
              description = "List of entity IDs of blind 'cover' entities";
            };
          };

          config.lovelace.sections = optional (blinds != [ ]) {
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
            ++ map (id: {
              type = "tile";
              name = blindName id;
              entity = "cover.${id}";
              features = singleton {
                type = "cover-open-close";
              };
              grid_options.rows = "auto";
            }) blinds;
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
      mkIf (blinds != [ ]) {
        cover = singleton {
          platform = "group";
          name = "${formattedRoomName} Blinds";
          entities = map (blind: "cover.${blind}") blinds;
        };
      }
    ) cfg.rooms
  );
}
