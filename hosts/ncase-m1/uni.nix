{
  lib,
  config,
  inputs,
  username,
  ...
}:
let
  inherit (lib) ns mkForce;
in
{
  ${ns} = {
    device = {
      address = mkForce null;
      vpnAddress = "192.168.100.12";
      altAddresses = mkForce [ ];
      hassIntegration.enable = mkForce false;

      monitors = mkForce [
        {
          name = "DP-1";
          number = 1;
          refreshRate = 144.0;
          gamingRefreshRate = 165.0;
          gamma = 0.75;
          width = 2560;
          height = 1440;
          position.x = 2560;
          position.y = 0;
          workspaces = builtins.genList (i: i + 1) 25;
        }
      ];
    };

    hardware = {
      scanner.enable = mkForce false;
      printing.client.enable = mkForce false;
      valve-index.enable = mkForce false;
      fanatec.enable = mkForce false;
    };

    programs = {
      gaming.steam.lanTransfer = mkForce false;
    };

    services = {
      wireguard = {
        home-minimal = {
          enable = true;
          autoStart = true;
          address = "192.168.100.12";
          subnet = 24;

          peers = lib.singleton {
            publicKey = "4kLZt3aTWUbqSZhz5Q64izTwA4qrDfnkso0z8gRfJ1Q=";
            presharedKeyFile = config.age.secrets.wg-home-router-psk.path;
            allowedIPs = [ "192.168.0.0/16" ];
            endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString inputs.nix-resources.secrets.homeWgRouterPort}";
          };

          dns = {
            enable = true;
            address = "192.168.100.1";
          };
        };

        home = {
          enable = true;
          autoStart = false;
          address = "192.168.100.12";
          subnet = 24;
          conflicts = [ "home-minimal" ];

          peers = lib.singleton {
            publicKey = "4kLZt3aTWUbqSZhz5Q64izTwA4qrDfnkso0z8gRfJ1Q=";
            presharedKeyFile = config.age.secrets.wg-home-router-psk.path;
            allowedIPs = [ "0.0.0.0/0" ];
            endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${toString inputs.nix-resources.secrets.homeWgRouterPort}";
          };

          dns = {
            enable = true;
            address = "192.168.100.1";
          };
        };
      };
    };

    system = {
      networking = {
        firewall.defaultInterfaces = mkForce [ "wg-home" ];
        wireless.disableOnBoot = mkForce false;
      };
    };
  };

  home-manager.users.${username} = {
    ${ns} = {
      desktop.services.darkman = {
        switchMethod = mkForce "coordinates";
      };
    };
  };
}
