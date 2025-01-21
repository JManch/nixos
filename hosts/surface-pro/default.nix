{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  ${lib.ns} = {
    device = {
      type = "laptop";
      memory = 1024 * 8;
      backlight = "intel_backlight";

      cpu = {
        name = "i5 7300U";
        type = "intel";
        cores = 4;
      };

      monitors = [
        {
          name = "eDP-1";
          number = 1;
          refreshRate = 60.0;
          width = 2736;
          height = 1824;
          scale = 1.5;
          position.x = 0;
          position.y = 0;
          workspaces = builtins.genList (i: (i * 2) + 1) 25;
        }
      ];
    };

    core.homeManager.enable = true;

    hardware = {
      bluetooth.enable = true;

      fileSystem = {
        type = "ext4";
        ext4.trim = true;
      };
    };

    system = {
      impermanence.enable = true;
      ssh.server.enable = true;
      audio.enable = true;

      desktop = {
        enable = true;
        desktopEnvironment = null;
        displayManager.name = "uwsm";
        uwsm.defaultDesktop = "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
      };

      networking = {
        tcpOptimisations = true;
        resolved.enable = true;

        firewall = {
          enable = true;
          defaultInterfaces = [ "wlp1s0" ];
        };

        wireless = {
          enable = true;
          onlyWpa2 = true;
          interface = "wlp1s0";
        };
      };
    };
  };
}
