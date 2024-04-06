{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
{
  assertions = lib.utils.asserts [
    (config.modules.services.wireguard.friends.enable -> config.age.secrets."${hostname}FriendsWGKey" != null)
    "A secret key for the host must be configured to use the friends Wireguard VPN"
  ];

  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wg-quick.interfaces = {
    wg-friends =
      let
        cfg = config.modules.services.wireguard.friends;
      in
      lib.mkIf cfg.enable {
        # Public keys
        # NCASE-M1 PFt9p3zx8nAYjU9pbNVRGS4QIvU/Tb18DdVowbcLuFc=
        # HOMELAB 6dVabb2p5miQ5NR0SQJ9oxhgjLMsNnuGhbHJGvanYS4=

        # Unlike the allowedIPs setting, the subnet mask here (/24) doesn't
        # represent a group of 256 IP addresses, it represents the network
        # mask for the interface. Since the subnet mask is 255.255.255.0, it
        # tells the interface that other devices on the network will have IP
        # addresses in that range. It is used for routing to determine if a
        # destination IP address is on the same network and if it can be directly
        # communicated with rather than going through the default gateway.
        address = [ "${cfg.address}/24" ];
        autostart = cfg.autoStart;
        privateKeyFile = config.age.secrets."${hostname}FriendsWGKey".path;
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

  programs.zsh =
    let
      inherit (lib) listToAttrs concatMap nameValuePair attrNames filter substring stringLength;
      cfg = config.modules.services.wireguard;
    in
    {
      shellAliases = listToAttrs (concatMap
        (interface: [
          (nameValuePair "${interface}-up" "sudo systemctl start wg-quick-${interface}")
          (nameValuePair "${interface}-down" "sudo systemctl stop wg-quick-${interface}")
        ])
        (filter
          (
            interface:
            let opt = cfg.${substring 3 (stringLength interface) interface}; in
            opt.enable && !opt.autoStart
          )
          (attrNames config.networking.wg-quick.interfaces)));
    };
}
