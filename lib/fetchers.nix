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
    in
    homeConfig: elem homeConfig.modules.desktop.windowManager waylandWindowManagers;

  getMonitorHyprlandCfgStr = m:
    "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${m.position},1,transform,${toString m.transform}${optionalString (m.mirror != null) ",mirror,${m.mirror}"}";
}
