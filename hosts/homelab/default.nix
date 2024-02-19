{
  imports = [ ./hardware-configuration.nix ];

  networking.hostId = "8d4ed64c";

  device = {
    type = "server";
    cpu.type = "amd";
    gpu.type = null;
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
      caddy.enable = true;
    };

    system = {
      networking = {
        tcpOptimisations = true;
        firewall.enable = true;
        # TODO: Need to think about this
        resolved.enable = false;
      };
    };
  };

  virtualisation.vmVariant = {
    virtualisation = {
      # TODO: Make this modular based on host spec
      memorySize = 4096; # Use 2048MiB memory.
      cores = 8;
    };
  };
}
