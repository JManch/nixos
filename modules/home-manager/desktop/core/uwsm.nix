{ lib, ... }:
let
  inherit (lib) ns types mkOption;
in
{
  options.${ns}.desktop.uwsm = {
    serviceApps = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of application desktop entry IDs that should be started in
        services instead of scopes. Useful for applications where we want to
        define custom shutdown behaviour.
      '';
    };

    appUnitOverrides = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Attribute set of unit overrides. Attribute name should be the unit
        name without the app-''${desktop} prefix. Attribute value should be
        the multiline unit string.
      '';
    };
  };
}
