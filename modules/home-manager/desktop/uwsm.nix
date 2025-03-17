{ lib, pkgs }:
let
  inherit (lib) types mkOption;
in
{
  enableOpt = false;
  conditions = [ "osConfig.system.desktop.uwsm" ];

  opts = {
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

  # Not perfect as it won't work for apps that wrap themselves with xdg-utils.
  # Don't want to overlay xdg-utils to avoid mass rebuilds.
  home.packages = [
    (lib.hiPrio (
      pkgs.runCommand "app2unit-xdg-open" { } ''
        mkdir -p $out/bin
        ln -s ${pkgs.app2unit}/bin/app2unit-open $out/bin/xdg-open
      ''
    ))
  ];
}
