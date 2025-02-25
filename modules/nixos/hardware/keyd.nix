{ lib, cfg }:
{
  opts = {
    swapCapsControl = lib.mkEnableOption "swapping caps lock and left control";
    swapAltMeta = lib.mkEnableOption "swapping left alt and left meta";

    excludedDevices = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "04fe:0021:5b3ab73a" ];
      description = "List of devices to exclude from keyd";
    };
  };

  services.keyd = {
    enable = true;
    keyboards.main = {
      ids = [ "*" ] ++ map (d: "-${d}") cfg.excludedDevices;
      settings.main = lib.mkMerge [
        (lib.mkIf cfg.swapCapsControl {
          capslock = "layer(control)";
          leftcontrol = "capslock";
        })

        (lib.mkIf cfg.swapAltMeta {
          leftmeta = "layer(alt)";
          leftalt = "layer(meta)";
        })
      ];
    };
  };
}
