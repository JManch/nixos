{
  lib,
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

  ns.userPackages = [ pkgs.overskride ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
      "size 40% 70%, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
      "center, class:^(io\\.github\\.kaii_lb\\.Overskride)$"
    ];
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
