lib:
{
  primaryMonitor = osConfig: lib.lists.findFirst (m: m.number == 1) (throw "Attempted to access primary monitors but monitor config has not been set.") osConfig.device.monitors;
  getMonitorByNumber = osConfig: number: lib.lists.findFirst (m: m.number == number) (builtins.head osConfig.device.monitors) osConfig.device.monitors;
  isGammaCustom = osConfig: !isNull (lib.lists.findFirst (m: m.gamma != 1.0) null osConfig.device.monitors);
  isWayland =
    let
      waylandWindowManagers = [
        "hyprland"
        "sway"
      ];
    in
    homeConfig: builtins.elem homeConfig.modules.desktop.windowManager waylandWindowManagers;
  getMonitorHyprlandCfgStr = m: "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${m.position},1";
}
