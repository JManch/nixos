{
  imports = [ ./hardware-configuration.nix ];

  device = {
    type = "desktop";
    # TODO: Double check this
    ipAddress = "192.168.88.220";
    memory = 1024;

    cpu = {
      name = "Cortex-A53";
      type = "arm";
      cores = "4";
    };
  };

  modules = {
    core.homeManager.enable = false;

    hardware.fileSystem = {
      type = "sdImage";
    };

    system = {
      audio.enable = true;
      ssh.server.enable = true;
      # Cross compilation build fails
      ssh.agent.enable = false;

      desktop = {
        enable = true;
        desktopEnvironment = "xfce";
      };

      networking = {
        primaryInterface = "enu1u1u1";
        useNetworkd = true;
        wireless = {
          enable = true;
          interface = "wlan0";
        };
      };
    };
  };
}
