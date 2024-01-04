lib:
{
  primaryMonitor = nixosConfig: lib.lists.findFirst (m: m.number == 1) (throw "Attempted to access primary monitors but monitor config has not been set.") nixosConfig.device.monitors;
  getMonitorByNumber = nixosConfig: number: lib.lists.findFirst (m: m.number == number) (builtins.head nixosConfig.device.monitors) nixosConfig.device.monitors;
  getDesktopSessionTarget =
    let
      sessionTargets = {
        "hyprland" = "hyprland-session.target";
      };
    in
    homeConfig: sessionTargets.${homeConfig.modules.desktop.windowManager};
  isWayland =
    let
      waylandWindowManagers = [
        "hyprland"
        "sway"
      ];
    in
    homeConfig: builtins.elem homeConfig.modules.desktop.windowManager waylandWindowManagers;
}
