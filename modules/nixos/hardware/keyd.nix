{ lib, cfg }:
let
  inherit (lib) mkIf mkMerge;
in
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

    hhkbArrowLayer = mkEnableOption ''
      a HHKB-like right shift arrow layer. Unfortunately not compatible with 
      unique left and right shift keys https://github.com/rvaiya/keyd/issues/771.
    '';
  };

  services.keyd = {
    enable = true;
    keyboards.main = {
      ids = [ "*" ] ++ map (d: "-${d}") cfg.excludedDevices;
      settings = mkMerge [
        {
          main = {
            # Be default keyd remaps all right keys to left keys. We'd like
            # to keep rightshift functionality although this can't be
            # achieved when rightshift activates a layer.
            # https://github.com/rvaiya/keyd/issues/114
            # https://github.com/rvaiya/keyd/issues/773
            rightshift = if cfg.hhkbArrowLayer then "layer(hhkb_arrows)" else "rightshift";
          }
          // cfg.rebinds;

        }

        (mkIf cfg.hhkbArrowLayer {
          hhkb_arrows = {
            semicolon = "left";
            apostrophe = "right";
            leftbrace = "up";
            slash = "down";
          };
        })
      ];
    };
  };
}
