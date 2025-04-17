# Friends VPN public keys
# NCASE-M1 PFt9p3zx8nAYjU9pbNVRGS4QIvU/Tb18DdVowbcLuFc=
# HOMELAB 6dVabb2p5miQ5NR0SQJ9oxhgjLMsNnuGhbHJGvanYS4=

# Explanation of wg-quick routing based off https://archive.is/tAvr4

# On Linux, there are multiple routing tables. Routing tables are chosen using
# 'rules'. Wireguard quick creates its own routing table, and uses custom rules
# to route traffic through it. Rules can be viewed with the `ip rule` command.

# Wireguard quick creates two ip rules:

# 32764:	from all lookup main suppress_prefixlength 0
# 32765:	not from all fwmark 0xca6c lookup 51820

# The first rules tells the kernel to use the 'main' routing table for all
# traffic EXCEPT traffic that matched the 'default' route in main. This works
# because suppress_prefixlength 0 suppresses all traffic where the prefix /0 is
# <= 0. If the traffic does not match this rule (because it used the default
# route and was suppressed) we move on to the next rule. This rule tells the
# kernel to use the routing table 51820 (custom routing table created by
# wireguard) for all traffic except traffic that has the fwmark. The fwmark
# basically prevents VPN traffic loops.

# To summarise, this system means that wireguard will route all traffic
# matching the default route in our "main" routing table through the VPN. We
# can bypass the VPN for specific subnets by configuring temporary custom
# routes in the PreUp and PostDown wireguard hooks. Here is a standard routing
# table:

# default via 192.168.88.1 dev eno1 proto dhcp src 192.168.88.254 metric 1002
# 192.168.88.0/24 dev eno1 proto dhcp scope link src 192.168.88.254 metric 1002

# The "default" route will be matched for ALL traffic that does not match any
# other routes. With this routing table, traffic matching the 192.168.88.0/24
# route will NOT be routed through the VPN.

# Be careful when adding custom routes as their subnets must not encapsulate
# the subnets of any existing routes.
{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    all
    getExe
    getExe'
    mapAttrsToList
    optional
    hasAttr
    mapAttrs
    attrNames
    concatMapStringsSep
    flatten
    removePrefix
    substring
    mkMerge
    mkEnableOption
    mkOption
    types
    ;
  inherit (config.${ns}.services) dns-stack;
  inherit (lib.${ns}) asserts;
  interfaces = config.${ns}.services.wireguard;

  wgSubmodule = types.submodule {
    options = {
      enable = mkEnableOption "the wireguard interface";
      autoStart = mkEnableOption "auto start";
      routerPeer = mkEnableOption "my router as a peer";

      address = mkOption {
        type = types.str;
        default = null;
        example = "10.0.0.2/24";
        description = "Assigned IP address for this device on the VPN along with the subnet mask";
      };

      listenPort = mkOption {
        type = with types; nullOr port;
        default = null;
        example = "51820";
        description = ''
          Optional port for Wireguard to listen on. Useful on for static
          clients that need a reliable VPN connection (persistent keep
          alive can be temperamental). If set, will open the port in the
          firewall and disable persistent keep alive. Note that this
          client's peers must manually specify the endpoint address and
          port.
        '';
      };

      subnet = mkOption {
        type = types.int;
        default = null;
        example = "24";
        description = "Subnet of the wireguard network";
      };

      routerAllowedIPs = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "List of allowed IPs for router peer";
      };

      peers = mkOption {
        type = with types; listOf attrs;
        default = [ ];
        description = "Wireguard peers";
      };

      dns = {
        enable = mkEnableOption "a custom DNS server for the VPN";
        host = mkEnableOption "hosting the custom DNS server on this host";

        domains = mkOption {
          type = with types; attrsOf str;
          default = { };
          example = {
            "example.com" = "10.0.0.4";
          };
          description = ''
            Attribute set of domains mapped to addresses. If systemd
            resolved is used the DNS server associated with this VPN will
            not longer be the default route. Instead, the configured
            domains will be added as DNS routing rules (in this case the
            address does not matter). This means that only DNS requests to
            these domains will be routed through the custom DNS server
            configured for the VPN.

            If `dns.host` is enabled, DNS redirect rules mapping domains to
            their addresses will be added to the DNS server.
          '';
        };

        address = mkOption {
          type = types.str;
          default = null;
          description = "Address of the device hosting the DNS server inside the VPN";
        };

        port = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Port for the DNS server to listen on";
        };
      };
    };
  };
in
{
  enableOpt = false;

  opts = mkOption {
    default = { };
    type = types.attrsOf wgSubmodule;
    description = "Wireguard VPN interfaces";
  };

  assertions = mkMerge (
    [
      (asserts [
        # Check that all configure firewall interfaces starting with "wg-" are
        # configured wireguard interfaces that are enabled
        (all (v: v == true) (
          map (
            interface:
            (
              if (substring 0 3 interface) != "wg-" then
                true
              else
                (hasAttr (removePrefix "wg-" interface) interfaces)
                && interfaces.${removePrefix "wg-" interface}.enable
            )
          ) (attrNames config.networking.firewall.interfaces)
        ))
        ''
          At least one of the wireguard interfaces (interface starting with
          'wg-') added to `networking.firewall.interfaces` is not a
          valid/enabled wireguard interface
        ''
      ])
    ]
    ++ mapAttrsToList (
      interface: cfg:
      asserts [
        (config.age.secrets."wg-${interface}-key" != null)
        "A private key secret for Wireguard VPN interface '${interface}' is missing"
        (cfg.routerPeer -> config.age.secrets."wg-${interface}-router-psk" != null)
        "A pre shared key for Wireguard VPN interface '${interface}' router peer is missing"
        (cfg.routerPeer -> inputs.nix-resources.secrets ? "${interface}WgRouterPort")
        "The router peer port for Wireguard VPN interface '${interface}' is missing"
        (cfg.dns.host -> dns-stack.enable)
        "The DNS stack must be enabled on this host to allow VPN DNS hosting"
        (cfg.routerPeer -> cfg.routerAllowedIPs != [ ])
        ''
          The `routerAllowedIPs` list for Wireguard VPN interface ${interface}
          must not be empty if `routerPeer` is enabled
        ''
      ]
    ) interfaces
  );

  networking = mkMerge (
    mapAttrsToList (
      interface: cfg:
      mkIf cfg.enable {
        wg-quick.interfaces."wg-${interface}" =
          let
            iptables = getExe' pkgs.iptables "iptables";
            resolvectl = getExe' pkgs.systemd "resolvectl";
          in
          {
            # Unlike the allowedIPs setting, the subnet mask here represents
            # the network mask for the interface. It tells the interface that
            # other devices on the network will have IP addresses in this
            # subnet.
            address = [ "${cfg.address}/${toString cfg.subnet}" ];
            listenPort = cfg.listenPort;
            autostart = cfg.autoStart;
            privateKeyFile = config.age.secrets."wg-${interface}-key".path;
            dns = mkIf cfg.dns.enable [ cfg.dns.address ];

            peers =
              cfg.peers
              ++ optional cfg.routerPeer {
                publicKey = "PbFraM0QgSnR1h+mGwqeAl6e7zrwGuNBdAmxbnSxtms=";
                presharedKeyFile = mkIf (
                  config.age.secrets ? "wg-${interface}-router-psk"
                ) config.age.secrets."wg-${interface}-router-psk".path;
                allowedIPs = cfg.routerAllowedIPs;
                endpoint = "${inputs.nix-resources.secrets.mikrotikDDNS}:${
                  toString inputs.nix-resources.secrets."${interface}WgRouterPort"
                }";
                persistentKeepalive = mkIf (cfg.listenPort == null) 25;
              };

            # Route incoming DNS traffic on the wireguard interface to the DNS server
            # port. We do not use standard port 53 for the wireguard DNS server
            # because that port is most likely taken.
            # TODO: Use nftables instead here. Useful guide: https://www.procustodibus.com/blog/2021/11/wireguard-nftables/
            preUp = mkIf cfg.dns.host ''
              ${iptables} -t nat -A PREROUTING -i wg-${interface} -p udp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
              ${iptables} -t nat -A PREROUTING -i wg-${interface} -p tcp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
            '';

            # In order for custom DNS domain routing rules to work we have to
            # add the domains with a custom command instead of using the
            # wg-quick config because wg-quick uses `resolveconf -x` which
            # adds an unwanted ~. domain routing rule.
            postUp = mkIf (cfg.dns.enable && (cfg.dns.domains != { }) && config.services.resolved.enable) ''
              ${resolvectl} default-route wg-${interface} false
              ${resolvectl} domain wg-${interface} ${
                concatMapStringsSep " " (domain: "\"~${domain}\"") (attrNames cfg.dns.domains)
              }
            '';

            postDown = mkIf cfg.dns.host ''
              ${iptables} -t nat -D PREROUTING -i wg-${interface} -p udp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
              ${iptables} -t nat -D PREROUTING -i wg-${interface} -p tcp --dport 53 -j REDIRECT --to-port ${toString cfg.dns.port}
            '';
          };

        # If we are not using the VPN's DNS server and it has custom hosts
        # configured, add them to our systems hosts file. This enables VPN
        # hostnames without needing to switch DNS servers.
        hosts = mkIf (!cfg.dns.enable && hasAttr interface inputs.nix-resources.secrets.wireguardHosts) (
          mapAttrs (_: v: [ "${v}.${interface}" ]) inputs.nix-resources.secrets.wireguardHosts.${interface}
        );

        firewall.allowedUDPPorts = optional (cfg.listenPort != null) cfg.listenPort;

        # Open DNS ports if we are hosting a DNS server
        firewall.interfaces."wg-${interface}" = mkIf cfg.dns.host {
          allowedTCPPorts = [ cfg.dns.port ];
          allowedUDPPorts = [ cfg.dns.port ];
        };
      }
    ) interfaces
  );

  systemd.services = mkMerge (
    mapAttrsToList (
      interface: cfg:
      mkMerge [
        (mkIf cfg.enable {
          "wg-quick-wg-${interface}" = {
            # Endpoints require DNS resolution which sometimes fails due to
            # ordering issues
            # https://discourse.nixos.org/t/name-resolution-fails-at-boot-time/33867
            # https://github.com/NixOS/nixpkgs/issues/260402
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = 30;
            };
          };
        })

        (mkIf (cfg.enable && cfg.dns.host) {
          "dnsmasq-wg-${interface}" =
            let
              # Use dns-stack dnsmsaq config as baseline
              settings = dns-stack.dnsmasqConfig // {
                port = cfg.dns.port;

                address = flatten (
                  mapAttrsToList (domain: address: [
                    "/${domain}/${address}"
                    "/${domain}/" # respond with NXDOMAIN for ipv6
                  ]) cfg.dns.domains
                );

                host-record = mapAttrsToList (
                  address: hostname: "${hostname}.${interface},${address}"
                ) inputs.nix-resources.secrets.wireguardHosts.${interface};
              };

              configFile = dns-stack.generateDnsmasqConfig "dnsmasq-wg-${interface}.conf" settings;
              dnsmasq = getExe pkgs.dnsmasq;
              baseline = config.systemd.services.dnsmasq;
            in
            {
              description = "wg-${interface} dnsmasq";
              after = [
                "network.target"
                "wg-quick-wg-${interface}.service"
              ];
              partOf = [ "wg-quick-wg-${interface}.service" ];
              requires = [ "wg-quick-wg-${interface}.service" ];
              wantedBy = [ "wg-quick-wg-${interface}.service" ];

              serviceConfig = baseline.serviceConfig // {
                ExecStartPre = "${dnsmasq} -C ${configFile} --test";
                ExecStart = "${dnsmasq} -k --user=dnsmasq -C ${configFile}";
                SocketBindAllow = cfg.dns.port;

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
              };
            };
        })
      ]
    ) interfaces
  );

  programs.zsh.shellAliases = mkMerge (
    mapAttrsToList (
      interface: cfg:
      mkIf (cfg.enable && !cfg.autoStart) {
        "wg-${interface}-up" = "sudo systemctl start wg-quick-wg-${interface}";
        "wg-${interface}-down" = "sudo systemctl stop wg-quick-wg-${interface}";
      }
    ) interfaces
  );
}
