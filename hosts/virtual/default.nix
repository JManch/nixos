{ lib, ... } @ args:
let
  inherit (lib) utils getExe;
  homeConfig = utils.homeConfig args;
in
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostId = "8d4ed64c";

  device = {
    type = "vm";
    cpu.type = null;
    gpu.type = null;

    monitors = [{
      name = "Virtual-1";
      number = 1;
      refreshRate = 60.0;
      width = 1920;
      height = 1080;
      position = "0x0";
      workspaces = [ 1 2 3 4 5 6 7 8 9 ];
    }];
  };

  usrEnv = {
    homeManager.enable = true;

    desktop = {
      enable = true;
      desktopEnvironment = null;
    };
  };

  modules = {
    hardware = {
      fileSystem = {
        trim = false;
        zpoolName = "zpool";
        bootLabel = "boot";
      };
    };

    services = {
      greetd = {
        enable = true;
        launchCmd = getExe homeConfig.wayland.windowManager.hyprland.package;
      };
    };

    system = {
      networking = {
        tcpOptimisations = true;
        firewall.enable = false;
        resolved.enable = true;
      };
    };
  };
}
