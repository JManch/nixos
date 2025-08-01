{ lib, osConfig }:
let
  inherit (lib)
    ns
    types
    mkOption
    mkEnableOption
    ;
  inherit (osConfig.${ns}.core) device;
in
{
  enableOpt = true;
  noChildren = true;

  opts = {
    bottom = mkEnableOption "positioning the bar at the bottom";

    float = mkOption {
      type = types.bool;
      default = device.type != "laptop";
      description = "Whether to add gaps and curved borders around the bar";
    };

    autoHideWorkspaces = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of workspace names that, when activated, cause the bar to
        automatically hide. Only works on Hyprland.
      '';
    };

    powerOffMethod = mkOption {
      type = types.enum [
        "suspend"
        "hibernate"
        "poweroff"
      ];
      default = "suspend";
      description = ''
        Power off method used when clicking power button
      '';
    };
  };
}
