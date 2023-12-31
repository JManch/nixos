lib: {
  primaryMonitor = config: lib.lists.findFirst (m: m.number == 1) (throw "Attempted to access primary monitors but monitor config has not been set.") config.device.monitors;
  getMonitorByNumber = config: number: lib.lists.findFirst (m: m.number == number) (builtins.head config.device.monitors) config.device.monitors;
}
