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
          inherit (config) sensors;
          inherit (config.airConditioning) climateId;
        in
        {
          options = {
            airConditioning = {
              enable = mkEnableOption "air conditioning integration";

              climateId = mkOption {
                type = types.str;
                description = "Entity ID of the climate sensor";
                example = "joshua_ac_room_temperature";
              };
            };
          };

          config.lovelace.sections = optional config.airConditioning.enable {
            title = "Air Conditioning";
            priority = 2;
            type = "grid";
            cards = [
              {
                name = " ";
                type = "thermostat";
                entity = "climate.${climateId}";
                features = singleton { type = "climate-hvac-modes"; };
              }
              {
                name = "Temperature";
                type = "sensor";
                graph = "line";
                entity = "sensor.${sensors.temperature}";
                detail = 2;
              }
              {
                name = "Humidity";
                type = "sensor";
                graph = "line";
                entity = "sensor.${sensors.humidity}";
                detail = 2;
              }
            ];
          };
        }
      )
    );
  };
}
