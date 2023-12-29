lib: {
  primaryMonitor = config: lib.lists.findFirst (m: m.number == 1) (throw "Attempted to access primary monitors but monitor config has not been set.") config.desktop.monitors;
  getMonitorByNumber = config: number: lib.lists.findFirst (m: m.number == number) (throw "Monitor number ${builtins.toString number} is not defined.") config.desktop.monitors;

  # TODO: Setup desktop session target
  # desktopSessionTarget = config:
}
