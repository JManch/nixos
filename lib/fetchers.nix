lib:
let
  inherit (lib) findFirst elem any head optionalString;
in
{
  primaryMonitor = osConfig:
    findFirst (m: m.number == 1)
      (throw "Attempted to access primary monitors but monitor config has not been set.")
      osConfig.device.monitors;

  getMonitorByNumber = osConfig:
    number: findFirst (m: m.number == number)
      (head osConfig.device.monitors)
      osConfig.device.monitors;

  isGammaCustom = osConfig:
    any (m: m.gamma != 1.0) osConfig.device.monitors;

  isWayland =
    let
      waylandWindowManagers = [
        "Hyprland"
        "sway"
      ];

      waylandDesktopEnvironments = [
        "gnome"
        "plasma"
      ];
    in
    osConfig: hmConfig: (elem osConfig.modules.system.desktop.desktopEnvironment waylandDesktopEnvironments) ||
      # When called from os, hmConfig should be a bool indicating whether or not
      # home manager is enabled. When called from home manager, hmConfig should
      # be config. We do this because hmConfig config cannot be accessed
      # through osConfig from home-manager as it causes infinite recursion.
      (if (builtins.typeOf hmConfig == "bool" && hmConfig) then
        elem osConfig.home-manager.users.${osConfig.modules.core.username}.modules.desktop.windowManager waylandWindowManagers
      else if (builtins.typeOf hmConfig != "bool") then
        elem hmConfig.modules.desktop.windowManager waylandWindowManagers
      else false);

  getMonitorHyprlandCfgStr = m:
    "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.position.x}x${toString m.position.y},1,transform,${toString m.transform}${optionalString (m.mirror != null) ",mirror,${m.mirror}"}";
}
