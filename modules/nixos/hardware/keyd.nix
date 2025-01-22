{ lib, config, ... }:
let
  inherit (lib) ns mkIf mkMerge;
  cfg = config.${ns}.hardware.keyd;
in
mkIf cfg.enable {
  services.keyd = {
    enable = true;
    keyboards.main = {
      ids = [ "*" ] ++ map (d: "-${d}") cfg.excludedDevices;
      settings.main = mkMerge [
        (mkIf cfg.swapCapsControl {
          capslock = "layer(control)";
          leftcontrol = "capslock";
        })

        (mkIf cfg.swapAltMeta {
          leftmeta = "layer(alt)";
          leftalt = "layer(meta)";
        })
      ];
    };
  };
}
