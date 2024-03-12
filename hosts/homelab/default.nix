{
  imports = [ ./hardware-configuration.nix ];

  networking.hostId = "8d4ed64c";

  device = {
    type = "server";
    cpu.type = "amd";
    gpu.type = null;
    ipAddress = "192.168.89.2";
  };

  usrEnv = {
    homeManager.enable = true;
    desktop.enable = false;
  };

  modules = {
    hardware = {
      fileSystem = {
        trim = true;
        zpoolName = "zpool";
        bootLabel = "boot";
      };
    };

    services = {
      home-assistant.enable = true;

      caddy = {
        enable = false;
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
        firewall.enable = true;
        tcpOptimisations = true;
        forceNoDHCP = true;
      };
    };
  };
}
