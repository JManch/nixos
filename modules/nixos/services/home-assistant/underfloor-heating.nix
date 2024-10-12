{ ns, lib, ... }:
let
  inherit (lib)
    types
    mkOption
    optional
    mkEnableOption
    singleton
    ;
in
{
  options.${ns}.services.hass.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { config, ... }:
        let
          inherit (config.underfloorHeating) climateId;
        in
        {
          options = {
            underfloorHeating = {
              enable = mkEnableOption "underfloor heating integration";

              climateId = mkOption {
                type = types.str;
                description = "Entity ID of the climate sensor";
                example = "joshua_underfloor_heating";
              };
            };
          };

          config.lovelace.sections = optional config.underfloorHeating.enable {
            title = "Underfloor Heating";
            priority = 3;
            type = "grid";
            cards = [
              {
                name = " ";
                type = "thermostat";
                entity = "climate.${climateId}";
                features = singleton { type = "climate-hvac-modes"; };
              }
              {
                type = "history-graph";
                show_names = true;
                entities = [ { entity = "climate.${climateId}"; } ];
              }
            ];
          };
        }
      )
    );
  };
}
