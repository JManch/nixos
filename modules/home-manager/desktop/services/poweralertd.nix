{
  lib,
  cfg,
  osConfig,
  ...
}:
let
  inherit (lib) ns mkIf foldl';
  inherit (osConfig.${ns}.core) device;
in
{
  enableOpt = false;

  opts.chargeThreshold =
    with lib;
    mkOption {
      type = types.nullOr types.number;
      default = null;
      description = ''
        Battery charge threshold so that notifications for charging at this level
        can be skipped.
      '';
    };

  conditions = [
    osConfig.services.upower.enable
    (device.battery != null)
  ];

  services.poweralertd = {
    enable = true;
    extraArgs = [
      "-s"
      "-i"
      "line power"
    ];
  };

  systemd.user.services."poweralertd" = {
    Unit.Requisite = [ "graphical-session.target" ];
    Service.Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
  };

  services.dunst.settings = mkIf (cfg.chargeThreshold != null) (
    foldl' (
      acc: percentage:
      acc
      // {
        "ignore_poweralertd_threshold_${toString percentage}" = {
          appname = "poweralertd";
          body = "Battery *Current level: ${toString percentage}%*";
          skip_display = true;
          history_ignore = true;
        };
      }
    ) { } (builtins.genList (i: cfg.chargeThreshold - 2 + i) 3)
  );
}
