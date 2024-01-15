{ lib
, pkgs
, config
, hostname
, ...
}:
let
  cfg = config.modules.services.wireguard;
in
lib.mkIf cfg.enable
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # Public keys
  # NCASE-M1 PlNilozIZ0FCYMOs1nVxVph33USmwh+o6nSouslvnU8=

  age.secrets.wireguardKey.file = ../../../secrets/wireguard/${hostname}/key.age;

  networking.firewall.interfaces.wg-discord =
    {
      # For OBS screensharing
      allowedTCPPorts = [ 5201 ];
      allowedUDPPorts = [ 5201 ];
    };

  networking.wg-quick.interfaces = {
    wg-discord = {
      address = [ "10.0.0.2/32" ];
      autostart = false;
      privateKeyFile = config.age.secrets.wireguardKey.path;
      listenPort = 13232;
      peers = [
        {
          publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
          allowedIPs = [ "10.0.0.1/24" ];
          endpoint = "ddns.manch.tech:13232";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  programs.zsh = {
    shellAliases = {
      wg-discord-up = "sudo systemctl start wg-quick-wg-discord";
      wg-discord-down = "sudo systemctl stop wg-quick-wg-discord";
    };
  };
}
