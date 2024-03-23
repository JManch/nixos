# DNS stack using a dnsmasq server and Ctrld DNS server. DNS requests first hit
# the dnsmasq server, which then sends the requests upstream to the Ctrld
# server. Using dnsmasq here has the advantage of more configurability than
# Ctrld and makes it possible to setup DNS resolution using the hosts file. We
# use Ctrld because it provides extra statistics to the web UI for monitoring.
{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mkIf mkForce mkVMOverride mapAttrs' nameValuePair filterAttrs utils;
  cfg = config.modules.services.dns-server-stack;

  # Patch Ctrld to enable loading endpoints from environment variables
  ctrld = outputs.packages.${pkgs.system}.ctrld.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../../../patches/ctrldSecretEndpoint.patch ];
  });
in
mkIf cfg.enable
{
  # Disable systemd-resolved to simplify DNS stack
  modules.system.networking.resolved.enable = mkForce false;

  services.ctrld = {
    enable = true;
    package = ctrld;

    settings = {
      service = {
        log_level = "notice";
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

  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = true;
    # Ignore this, just have to set it to false to workaround upstream issues
    resolveLocalQueries = false;

    settings = {
      port = cfg.listenPort;

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

      # Define local domain whose queries should never be forwarded upstream.
      # Expand hosts adds .lan to host file entries.
      local = "/lan/";
      domain = "lan";
      expand-hosts = true;

      # Send the entire source ip to the Ctrld DNS server. Otherwise Ctrld DNS
      # server sees all source requests coming from localhost. Note that this
      # disables dnsmasq caching so we instead cache with Ctrld.
      add-subnet = "32,128";
      filter-AAAA = !cfg.enableIPv6;

      # Send all queries to the Ctrld DNS server
      server = [ "127.0.0.1#${toString cfg.ctrldListenPort}" ];
      address = with inputs.nix-resources.secrets; [
        # Point DDNS domain to router
        "/ddns.${fqDomain}/${cfg.routerAddress}"

        # Point reverse proxy traffic to the device to avoid need for hairpin NAT
        "/${fqDomain}/${config.device.ipAddress}"
      ];
    };
  };

  # Home hosts file declares hostnames for all devices on my local network
  networking.hosts = inputs.nix-resources.secrets.homeHosts // {
    "${cfg.routerAddress}" = [ "router" ];
  } //
    # Add all hosts that have a static local address
    (mapAttrs'
      (host: v: nameValuePair (v.config.device.ipAddress) ([ host ]))
      (filterAttrs (host: v: v.config.device.ipAddress != null) (utils.hosts outputs)));

  # Open DNS ports in firewall and set nameserver to localhost
  networking.firewall.allowedTCPPorts = [ cfg.listenPort ];
  networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
  networking.nameservers = mkForce [ "127.0.0.1" ];

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
      CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      AmbientCapabilities = [ "CAP_CHOWN" "CAP_SETUID" "CAP_SETGID" "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
      SocketBindDeny = "any";
      SocketBindAllow = cfg.listenPort;
    };
  };

  # Enable extra debugging in our vmVariant and replace secrets
  virtualisation.vmVariant = {
    services.ctrld.settings = {
      service = {
        log_level = mkVMOverride "debug";
        log_path = "/tmp/ctrld.log";
      };
    };

    services.dnsmasq.settings = {
      log-queries = true;
    };
  };
}
