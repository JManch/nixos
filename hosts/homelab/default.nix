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
    hardware = {
      fileSystem.trim = true;
      fileSystem.extendedLoaderTimeout = true;
      graphics.hardwareAcceleration = true;
    };

    services = {
      hass.enable = true;
      unifi.enable = true;
      calibre.enable = true;
      mosquitto.enable = true;

      vaultwarden = {
        enable = true;
        adminInterface = false;
      };

      caddy = {
        enable = true;
        lanAddressRanges = [
          "192.168.88.0/24"
          "192.168.100.0/24"
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

      broadcast-box = {
        enable = true;
        port = 8081;
        autoStart = true;
        proxy = true;
      };

      zigbee2mqtt = {
        enable = true;
        deviceNode = "/dev/ttyACM0";
      };

      wireguard.friends = {
        enable = true;
        autoStart = true;
        routerPeer = true;
        routerAllowedIPs = [ "10.0.0.0/24" ];
        address = "10.0.0.7";
        dns = {
          host = true;
          port = 13233;
        };
      };

      scrutiny = {
        server.enable = true;
        collector.enable = true;
      };
    };

    system = {
      networking = {
        primaryInterface = "enp1s0";
        staticIPAddress = "192.168.89.2";
        defaultGateway = "192.168.89.1";
        firewall.enable = true;
        tcpOptimisations = true;
      };
    };
  };
}
