{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    all
    elem
    getExe
    getExe'
    attrsToList
    filterAttrs
    mapAttrsToList
    optional
    mapAttrs'
    listToAttrs
    concatMap
    nameValuePair
    attrNames
    removePrefix
    substring
    ;
  inherit (config.${ns}.services) dns-server-stack;
  inherit (inputs.nix-resources.secrets) fqDomain;
  interfaces = filterAttrs (_: cfg: cfg.enable) config.${ns}.services.wireguard;

  # Friends VPN public keys
  # NCASE-M1 PFt9p3zx8nAYjU9pbNVRGS4QIvU/Tb18DdVowbcLuFc=
  # HOMELAB 6dVabb2p5miQ5NR0SQJ9oxhgjLMsNnuGhbHJGvanYS4=

  dnsmasqConfig =
    name: cfg:
    let
      # Use dns-server-stack dnsmsaq config as baseline
      settings = dns-server-stack.dnsmasqConfig // {
        port = cfg.dns.port;

        address = [
          "/${fqDomain}/${cfg.address}"
          "/${fqDomain}/"
        ];

        host-record = mapAttrsToList (
          address: hostname: "${hostname}.lan,${address}"
        ) inputs.nix-resources.secrets."${name}WGHosts";
      };

      configFile = dns-server-stack.generateDnsmasqConfig "dnsmasq-wg-${name}.conf" settings;
      dnsmasq = getExe pkgs.dnsmasq;
      baseline = config.systemd.services.dnsmasq;
    in
    {
      unitConfig = baseline.unitConfig // {
        Description = "Dnsmasq daemon for ${name} wireguard VPN";
        PartOf = [ "wg-quick-${name}.service" ];
      };

      serviceConfig = baseline.serviceConfig // {
        ExecStartPre = "${dnsmasq} -C ${configFile} --test";
        ExecStart = "${dnsmasq} -k --user=dnsmasq -C ${configFile}";
        CapabilityBoundingSet = [
          "CAP_CHOWN"
          "CAP_SETUID"
          "CAP_SETGID"
        ];
        AmbientCapabilities = [
          "CAP_CHOWN"
          "CAP_SETUID"
          "CAP_SETGID"
        ];
        SocketBindAllow = cfg.dns.port;
      };

      wantedBy = [ "wg-quick-wg-${name}.service" ];
    };

  # Explanation of wg-quick routing based off https://archive.is/tAvr4

  # On Linux, there are are multiple routing tables. Routing tables are chosen
  # using 'rules'. Wireguard quick creates its own routing table, and uses
  # custom rules to route traffic through it. Rules can be viewed with the `ip
  # rule` command.

  # Wireguard quick creates two ip rules:

  # 32764:	from all lookup main suppress_prefixlength 0
  # 32765:	not from all fwmark 0xca6c lookup 51820

  # The first rules tells the kernel to use the 'main' routing table for all
  # traffic EXCEPT traffic that matched the 'default' route in main. This works
  # because suppress_prefixlength 0 suppresses all traffic where the prefix
  # /0 is <= 0. If the traffic does not match this rule because it used the
  # default route and was suppressed, we then move on to the next rule. This
  # rule tells the kernel to use the routing table 51820 (custom routing table
  # created by wireguard) for all traffic except traffic that has the fwmark.
  # The fwmark basically prevents VPN traffic loops.

  # Overall, this system means that wireguard will route all traffic matching
  # the default route in our "main" routing table through the VPN. We can
  # bypass the VPN for specific subnets by configuring temporary custom routes
  # in the PreUp and PostDown wireguard hooks. Here is a standard routing
  # table:

  # default via 192.168.88.1 dev eno1 proto dhcp src 192.168.88.254 metric 1002
  # 192.168.88.0/24 dev eno1 proto dhcp scope link src 192.168.88.254 metric 1002

  # The "default" route will be matched for ALL traffic that does not match any
  # other routes. With this routing table, traffic matching the 192.168.88.0/24
  # route will NOT be routed throught he VPN. This means that by default,
  # wireguard will not route local traffic through the VPN.

  # Be careful when adding custom routes as their subnets must not encapsulate
  # the subnets of any existing routes.

  interfaceConfig =
    name: cfg:
    let
      iptables = getExe' pkgs.iptables "iptables";
    in
    {
      # Unlike the allowedIPs setting, the subnet mask here (/24) doesn't
      # represent a group of 256 IP addresses, it represents the network
      # mask for the interface. Since the subnet mask is 255.255.255.0, it
      # tells the interface that other devices on the network will have IP
      # addresses in that range. It is used for routing to determine if a
      # destination IP address is on the same network and if it can be directly
      # communicated with rather than going through the default gateway.
      address = [ "${cfg.address}/${toString cfg.subnet}" ];
      autostart = cfg.autoStart;
      privateKeyFile = config.age.secrets."wg-${name}-key".path;
      dns = mkIf cfg.dns.enable [ cfg.dns.address ];

      peers =
        cfg.peers
        ++ optional (cfg.routerPeer) {
          publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
          allowedIPs = cfg.routerAllowedIPs;
          endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:13232";
          persistentKeepalive = 25;
        };

      # Route incoming DNS traffic on the wireguard interface to the DNS server
      # port. We do not use standard port 53 for the wireguard DNS server
      # because that port is most likely taken.
      # TODO: Use nftables instead here. Useful guide: https://www.procustodibus.com/blog/2021/11/wireguard-nftables/
      preUp = mkIf cfg.dns.host ''
        ${iptables} -t nat -A PREROUTING -i wg-${name} -p udp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
        ${iptables} -t nat -A PREROUTING -i wg-${name} -p tcp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
      '';

      postDown = mkIf cfg.dns.host ''
        ${iptables} -t nat -D PREROUTING -i wg-${name} -p udp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
        ${iptables} -t nat -D PREROUTING -i wg-${name} -p tcp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
      '';
    };
in
{
  assertions = lib.${ns}.asserts (
    (concatMap (
      interface:
      let
        name = interface.name;
        cfg = interface.value;
      in
      [
        (config.age.secrets."wg-${name}-key" != null)
        "A private key secret for the Wireguard VPN interface ${name} is missing"
        (cfg.dns.host -> dns-server-stack.enable)
        "The dns server stack must be enabled on this host to allow VPN dns hosting"
        (cfg.routerPeer -> (cfg.routerAllowedIPs != [ ]))
        "The routerAllowedIPs list for VPN ${name} must not be empty if routerPeer is enabled"
      ]
    ) (attrsToList interfaces))
    ++ [
      # Check that all interfaces starting with "wg-" in networking.firewall.interfaces are configured wireguard interfaces that are enabled
      (all (v: v == true) (
        map (
          interface:
          (
            if (substring 0 3 interface) != "wg-" then
              true
            else
              elem (removePrefix "wg-" interface) (attrNames interfaces)
          )
        ) (attrNames config.networking.firewall.interfaces)
      ))
      "At least one of the wireguard interfaces (interface starting with 'wg-') added to `networking.firewall.interfaces` is not a valid/enabled wireguard interface"
    ]
  );

  networking.wg-quick.interfaces = mapAttrs' (
    name: cfg: nameValuePair ("wg-" + name) (interfaceConfig name cfg)
  ) interfaces;

  networking.firewall.interfaces = mapAttrs' (
    name: cfg:
    nameValuePair ("wg-" + name) (
      mkIf cfg.dns.host {
        allowedTCPPorts = [ cfg.dns.port ];
        allowedUDPPorts = [ cfg.dns.port ];
      }
    )
  ) interfaces;

  systemd.services = mapAttrs' (
    name: cfg: nameValuePair ("dnsmasq-wg-" + name) (mkIf (cfg.dns.host) (dnsmasqConfig name cfg))
  ) interfaces;

  programs.zsh = {
    shellAliases = listToAttrs (
      concatMap (interface: [
        (nameValuePair "wg-${interface}-up" "sudo systemctl start wg-quick-wg-${interface}")
        (nameValuePair "wg-${interface}-down" "sudo systemctl stop wg-quick-wg-${interface}")
      ]) (attrNames (filterAttrs (_: cfg: !cfg.autoStart) interfaces))
    );
  };
}
