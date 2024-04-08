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
      settings = {
        port = cfg.dns.port;
        log-queries = true;
        no-hosts = true;
        domain-needed = true;
        bogus-priv = true;
        stop-dns-rebind = true;
        rebind-localhost-ok = true;
        no-resolv = true;
        no-poll = true;
        add-subnet = "32,128";
        filter-AAAA = true;

        server = [ "127.0.0.1#${toString dns-server-stack.ctrldListenPort}" ];

        address = [
          "/${fqDomain}/${cfg.address}"
          "/${fqDomain}/"
        ];

        host-record =
          attrValues
            (mapAttrs (address: hostname: "${hostname}.lan,${address}") inputs.nix-resources.secrets."${name}WGHosts");
      };

      configFile = settingsFormat.generate "dnsmasq-wg-${name}.conf" settings;

      formatKeyValue =
        name: value:
        if value == true
        then name
        else if value == false
        then "# setting `${name}` explicitly set to false"
        else lib.generators.mkKeyValueDefault { } "=" name value;

      settingsFormat = pkgs.formats.keyValue {
        mkKeyValue = formatKeyValue;
        listsAsDuplicateKeys = true;
      };
    in
    {
      unitConfig = {
        Description = "Dnsmasq daemon for ${name} wireguard VPN";
        PartOf = [ "wg-quick-${name}.service" ];
        After = [ "network.target" ];
      };

      serviceConfig = utils.hardeningBaseline config {
        ExecStartPre = "${getExe pkgs.dnsmasq} -C ${configFile} --test";
        ExecStart = "${getExe pkgs.dnsmasq} -k --user=dnsmasq -C ${configFile}";
        ExecReload = "${getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        Restart = "always";

        DynamicUser = false;
        PrivateUsers = false;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
        SystemCallFilter = [ "@system-service" "~@resources" ];
        CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" ];
        AmbientCapabilities = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" ];
        SocketBindDeny = "any";
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
      dns = mkIf (cfg.dns.enable && !cfg.dns.host) [ cfg.dns.address ];

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
        (nameValuePair "wg-${interface}-up" "sudo systemctl start wg-quick-${interface}")
        (nameValuePair "wg-${interface}-down" "sudo systemctl stop wg-quick-${interface}")
      ])
      (attrNames (filterAttrs (_: cfg: cfg.enable && !cfg.autoStart) interfaces)));
  };
}
