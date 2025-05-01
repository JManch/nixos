{
  lib,
  args,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  # WARN: Overskride has a horrendous bug where clicking on button toggles does
  # nothing (even though the toggle visually flips). Must click on the bars.
  # https://github.com/kaii-lb/overskride/issues/25
  ns.userPackages = [
    (lib.${ns}.wrapHyprlandMoveToActive args pkgs.overskride "io.github.kaii_lb.Overskride" "")
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
      "size 40% 70%, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
      "center, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
    ];
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
