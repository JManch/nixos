{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  networking.hostId = "8d4ed64c";

  device = {
    type = "server";
    cpu.type = "amd";
    cpu.cores = 4;
    memory = 8000;
    gpu.type = null;
    ipAddress = "192.168.89.2";
  };

  usrEnv = {
    homeManager.enable = true;
    desktop.enable = false;
  };

  modules = {
    hardware.fileSystem.trim = true;
    hardware.graphics.hardwareAcceleration = true;

    services = {
      hass.enable = true;
      unifi.enable = true;
      calibre.enable = true;
      mosquitto.enable = true;

      caddy = {
        enable = true;
        lanAddressRanges = [
          "192.168.0.0/16"
          "10.20.20.0/24"
        ];
      };

      dns-server-stack = {
        enable = true;
        routerAddress = "192.168.88.1";
        enableIPv6 = false;
      };

      frigate = {
        enable = true;
        nvrAddress = "192.168.88.229";
      };
    };

    system = {
      networking = {
        # TODO: Double check this in installer
        primaryInterface = "enp1s0";
        staticIPAddress = "192.168.89.2";
        defaultGateway = "192.168.89.1";
        firewall.enable = true;
        tcpOptimisations = true;
      };
    };
  };
}
