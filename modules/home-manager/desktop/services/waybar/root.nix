{ lib, osConfig }:
let
  inherit (lib) ns types mkOption;
  inherit (osConfig.${ns}.core) device;
in
{
  enableOpt = true;
  noChildren = true;

  opts = {
    float = mkOption {
      type = types.bool;
      default = device.type != "laptop";
      description = "Whether to add gaps and curved borders around the bar";
    };

    audioDeviceIcons = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Attribute set mapping audio devices to icons. Use pamixer --list-sinks
        to get device names.
      '';
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
