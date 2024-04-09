{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    getExe
    getExe'
    attrsToList
    filterAttrs
    attrValues
    mapAttrs
    optional
    mapAttrs'
    listToAttrs
    concatMap
    nameValuePair
    attrNames;
  inherit (config.modules.services) dns-server-stack;
  inherit (inputs.nix-resources.secrets) fqDomain;
  interfaces = config.modules.services.wireguard;

  # Friends VPN public keys
  # NCASE-M1 PFt9p3zx8nAYjU9pbNVRGS4QIvU/Tb18DdVowbcLuFc=
  # HOMELAB 6dVabb2p5miQ5NR0SQJ9oxhgjLMsNnuGhbHJGvanYS4=

  dnsmasqConfig = name: cfg:
    let
      # Use dns-server-stack dnsmsaq config as baseline
      settings = dns-server-stack.dnsmasqConfig // {
        port = cfg.dns.port;

        address = [
          "/${fqDomain}/${cfg.address}"
          "/${fqDomain}/"
        ];

        host-record =
          attrValues
            (mapAttrs (address: hostname: "${hostname}.lan,${address}") inputs.nix-resources.secrets."${name}WGHosts");
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
        CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" ];
        AmbientCapabilities = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" ];
        SocketBindAllow = cfg.dns.port;
      };

      wantedBy = [ "wg-quick-wg-${name}.service" ];
    };

  interfaceConfig = name: cfg:
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
      address = [ "${cfg.address}/24" ];
      autostart = cfg.autoStart;
      privateKeyFile = config.age.secrets."${hostname}-wg-${name}-key".path;
      dns = mkIf cfg.dns.enable [ cfg.dns.address ];

      peers = cfg.peers ++ optional (cfg.routerPeer) {
        publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
        allowedIPs = cfg.routerAllowedIPs;
        endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:13232";
        persistentKeepalive = 25;
      };

      postUp = mkIf cfg.dns.host ''
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
  assertions = utils.asserts (concatMap
    (interface:
      let
        name = interface.name;
        cfg = interface.value;
      in
      [
        (config.age.secrets."${hostname}-wg-${name}-key" != null)
        "A private key secret for the Wireguard VPN interface ${name} is missing"
        (cfg.dns.host -> dns-server-stack.enable)
        "The dns server stack must be enabled on this host to allow VPN dns hosting"
        (cfg.routerPeer -> (cfg.routerAllowedIPs != [ ]))
        "The routerAllowedIPs list for VPN ${name} must not be empty if routerPeer is enabled"
      ])
    (attrsToList (filterAttrs (_: cfg: cfg.enable) interfaces)));

  networking.wg-quick.interfaces = mapAttrs'
    (name: cfg: nameValuePair ("wg-" + name) (interfaceConfig name cfg))
    interfaces;

  networking.firewall.interfaces = mapAttrs'
    (name: cfg: nameValuePair ("wg-" + name) (mkIf cfg.dns.host {
      allowedTCPPorts = [ cfg.dns.port ];
      allowedUDPPorts = [ cfg.dns.port ];
    }))
    interfaces;

  systemd.services = mapAttrs'
    (name: cfg: nameValuePair ("dnsmasq-wg-" + name) (mkIf (cfg.dns.host) (dnsmasqConfig name cfg)))
    interfaces;

  programs.zsh = {
    shellAliases = listToAttrs (concatMap
      (interface: [
        (nameValuePair "wg-${interface}-up" "sudo systemctl start wg-quick-wg-${interface}")
        (nameValuePair "wg-${interface}-down" "sudo systemctl stop wg-quick-wg-${interface}")
      ])
      (attrNames (filterAttrs (_: cfg: cfg.enable && !cfg.autoStart) interfaces)));
  };
}
