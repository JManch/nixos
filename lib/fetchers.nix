lib:
{
  primaryMonitor = nixosConfig: lib.lists.findFirst (m: m.number == 1) (throw "Attempted to access primary monitors but monitor config has not been set.") nixosConfig.device.monitors;
  getMonitorByNumber = nixosConfig: number: lib.lists.findFirst (m: m.number == number) (builtins.head nixosConfig.device.monitors) nixosConfig.device.monitors;
  isGammaCustom = nixosConfig: !isNull (lib.lists.findFirst (m: m.gamma != 1.0) null nixosConfig.device.monitors);
  isWayland =
    let
      waylandWindowManagers = [
        "hyprland"
        "sway"
      ];
    in
    homeConfig: builtins.elem homeConfig.modules.desktop.windowManager waylandWindowManagers;
  getMonitorHyprlandCfgStr = m: "${m.name},${builtins.toString m.width}x${builtins.toString m.height}@${builtins.toString m.refreshRate},${m.position},1";
}
