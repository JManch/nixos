{lib, ...}: {
  primaryMonitor = config: lib.lists.findFirst (m: m.primary == true) null config.monitors;
  desktopSessionTarget = config: 
}
