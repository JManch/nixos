{ lib
, pkgs
, config
, inputs
, ...
}:
let
  cfg = config.modules.services.wireguard;
in
lib.mkIf cfg.enable
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  # Public keys
  # NCASE-M1 y0Yy2rslvqQmkWMyfOwkYoTGcvSODwvsTHmhcWhmtx4=

  networking.wg-quick.interfaces = {
    wg-discord = {
      # Unlike the allowedIPs setting, the subnet mask here (/24) doesn't
      # represent a group of 256 IP addresses, it represents the network
      # mask for the interface. Since the subnet mask is 255.255.255.0, it
      # tells the interface that other devices on the network will have IP
      # addresses in that range. It is used for routing to determine if a
      # destination IP address is on the same network and if it can be directly
      # communicated with rather than going through the default gateway.
      address = [ "10.0.0.2/24" ];
      autostart = false;
      privateKeyFile = config.age.secrets.wireguardKey.path;
      peers = [
        {
          publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
          allowedIPs = [ "10.0.0.0/24" ];
          endpoint = "ddns.${inputs.nix-resources.secrets.fqDomain}:13232";
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
