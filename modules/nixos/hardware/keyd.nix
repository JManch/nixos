{ lib, cfg }:
{
  enableOpt = false;
  conditions = [ (cfg.rebinds != { }) ];

  opts = with lib; {
    rebinds = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Rebinds to apply on the main profile";
    };

    excludedDevices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "04fe:0021:5b3ab73a" ];
      description = "List of devices to exclude from keyd";
    };
  };

  services.keyd = {
    enable = true;
    keyboards.main = {
      ids =
        [ "*" ]
        ++ map (d: "-${d}") (
          cfg.excludedDevices
          ++ [
            # always exclude hhkb
            "04fe:0021:5b3ab73a"
          ]
        );
      settings.main = cfg.rebinds;
    };
  };
}
