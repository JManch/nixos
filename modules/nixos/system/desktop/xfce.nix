{ categoryCfg }:
{
  enableOpt = false;
  conditions = [ (categoryCfg.desktopEnvironment == "xfce") ];

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };

  services.displayManager.defaultSession = "xfce";
}
