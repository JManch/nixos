{ lib }:
{
  enableOpt = true;
  noChildren = true;

  opts = with lib; {
    audioDeviceIcons = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Attribute set mapping audio devices to icons. Use pamixer --list-sinks to get device names.
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
  };
}
