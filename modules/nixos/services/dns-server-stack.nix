# DNS stack using a dnsmasq server and Ctrld DNS server. DNS requests first hit
# the dnsmasq server, which then sends the requests upstream to the Ctrld
# server. Using dnsmasq here has the advantage of more configurability than
# Ctrld and makes it possible to setup custom DNS resolution for devices on the
# local network. We use the Ctrld dns forwarding proxy because it provides
# extra statistics to the web UI for monitoring and enables DoH/3.
{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    mkVMOverride
    mapAttrs'
    mapAttrs
    attrValues
    nameValuePair
    filterAttrs
    utils;
  inherit (inputs.nix-resources.secrets) fqDomain mikrotikDDNS;
  inherit (config.modules.services) wireguard;
  cfg = config.modules.services.dns-server-stack;

  # Patch Ctrld to enable loading endpoints from environment variables
  ctrld = outputs.packages.${pkgs.system}.ctrld.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../../../patches/ctrldSecretEndpoint.patch ];
  });

  # Declares hostnames for all devices on my local network
  homeHosts = inputs.nix-resources.secrets.homeHosts // {
    "${cfg.routerAddress}" = "router";
  } //
    # Add all hosts that have a static local address
    mapAttrs'
      (host: v: nameValuePair v.config.device.ipAddress host)
      (filterAttrs (host: v: v.config.device.ipAddress != null) (utils.hosts outputs));
in
mkIf (hostname == "homelab" && cfg.enable)
{
  # Disable systemd-resolved to simplify DNS stack
  modules.system.networking.resolved.enable = mkForce false;

  services.ctrld = {
    enable = true;
    package = ctrld;

    settings = {
      service = {
        log_level = if cfg.debug then "trace" else "notice";
        cache_enable = true;
        # Disable all LAN discovery techniques apart from hosts because our
        # hosts file is extensive and we'd rather have manual control over this
        # than Ctrld performing network scans.
        discover_hosts = true;
        discover_mdns = false;
        discover_arp = false;
        discover_dhcp = false;
        discover_ptr = false;
      };

      listener."0" = {
        ip = "127.0.0.1";
        port = cfg.ctrldListenPort;
      };

      upstream = {
        "0" = {
          name = "Control D Main Profile";
          # The actual endpoint is loaded from an environment variable
          endpoint = "https://dns.controld.com/secret";
          bootstrap_ip = "76.76.2.22";
          type = "doh3";
        };

        "1" = {
          name = "Google";
          endpoint = "https://dns.google/dns-query";
          bootstrap_ip = "8.8.8.8";
          type = "doh";
        };
      };
    };
  };

  systemd.services.ctrld.serviceConfig = utils.hardeningBaseline config {
    EnvironmentFile = config.age.secrets.ctrldEndpoint.path;
  };

  # Populate hosts file for ctrld host discovery
  networking.hosts = mapAttrs (_: v: [ v ]) homeHosts;

  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = true;
    # Ignore this, just have to set it to false to workaround upstream issues
    resolveLocalQueries = false;

    settings = {
      port = cfg.listenPort;
      log-queries = cfg.debug;

      # Do not read from hosts because it contains an entry that points
      # ${hostname}.lan to ::1 and 127.0.0.2. Don't want this in responses so
      # instead we define hosts using the dnsmasq host-record option and keep
      # /etc/hosts for ctrld.
      no-hosts = true;

      # Never forward dns queries without a domain to upstream nameservers
      domain-needed = true;

      # Do not send reverse lookups for private ip ranges upstream
      bogus-priv = true;

      # Reject addresses from upstream nameservers that are in private ranges
      stop-dns-rebind = true;

      # Allow localhost reply from blackhole nameservers
      rebind-localhost-ok = true;

      # Do not read or poll resolv.conf, we manually configure servers
      no-resolv = true;
      no-poll = true;

      # Send the entire source ip to the Ctrld DNS server. Otherwise Ctrld DNS
      # server sees all source requests coming from localhost. Note that this
      # disables dnsmasq caching so we instead cache with Ctrld.
      add-subnet = "32,128";
      filter-AAAA = !cfg.enableIPv6;

      # Send all queries to the Ctrld DNS server
      server = [ "127.0.0.1#${toString cfg.ctrldListenPort}" ];

      address = [
        # Point DDNS domain to router
        "/ddns.${fqDomain}/${cfg.routerAddress}"

        # Point reverse proxy traffic to the device to avoid need for hairpin NAT
        "/${fqDomain}/${config.device.ipAddress}"
      ];

      # Host records create PTR entries as well. Using addn-hosts created
      # duplicate entries for some reason so using this instead.
      host-record =
        attrValues
          (mapAttrs (address: hostname: "${hostname}.lan,${address}") homeHosts);
    };
  };

  # Open DNS ports in firewall and set nameserver to localhost
  networking.firewall.allowedTCPPorts = [ cfg.listenPort ];
  networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
  networking.nameservers = mkForce [ "127.0.0.1" ];

  # Expose DNS on VPN
  networking.firewall.interfaces.wg-friends.allowedTCPPorts =
    mkIf wireguard.friends.enable [ cfg.listenPort ];
  networking.firewall.interfaces.wg-friends.allowedUDPPorts =
    mkIf wireguard.friends.enable [ cfg.listenPort ];

  # Harden the dnsmasq systemd service
  systemd.services.dnsmasq = {
    # The upstream service is very poorly configured
    preStart = mkForce "dnsmasq --test";
    restartTriggers = mkForce [ ];

    serviceConfig = utils.hardeningBaseline config {
      DynamicUser = false;
      PrivateUsers = false;
      ProtectSystem = mkForce "strict";
      RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
      SystemCallFilter = [ "@system-service" "~@resources" ];
      CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      AmbientCapabilities = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      SocketBindDeny = "any";
      SocketBindAllow = cfg.listenPort;
    };
  };

  # Enable extra debugging in our vmVariant and replace secrets
  virtualisation.vmVariant = {
    services.ctrld.settings = {
      service.log_level = mkVMOverride "trace";
    };

    services.dnsmasq.settings = {
      log-queries = mkVMOverride true;
    };
  };
}
