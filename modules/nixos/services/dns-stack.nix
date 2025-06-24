# DNS stack using a dnsmasq server and Ctrld DNS server. DNS requests first hit
# the dnsmasq server, which then sends the requests upstream to the Ctrld
# server. Using dnsmasq here has the advantage of more configurability than
# Ctrld and makes it possible to setup custom DNS resolution for devices on the
# local network. We use the Ctrld dns forwarding proxy because it provides
# extra statistics to the web UI for monitoring and enables DoH/3.
{
  lib,
  cfg,
  pkgs,
  self,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkForce
    mapAttrs'
    mapAttrs
    mapAttrsToList
    nameValuePair
    filterAttrs
    getExe
    getExe'
    genAttrs
    singleton
    ;
  inherit (lib.${ns}) addPatches hardeningBaseline;
  inherit (inputs.nix-resources.secrets) oldFqDomain fqDomain;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  inherit (config.${ns}.core) device;

  # Declares hostnames for all devices on my local network
  homeHosts =
    inputs.nix-resources.secrets.homeHosts
    // {
      "${cfg.routerAddress}" = "router";
    }
    //
      # Add all hosts that have a static local address
      mapAttrs' (host: v: nameValuePair v.config.${ns}.core.device.address host) (
        filterAttrs (host: v: v.config.${ns}.core.device.address != null) self.nixosConfigurations
      )
    # Add VPN variants
    // mapAttrs' (host: v: nameValuePair v.config.${ns}.core.device.vpnAddress "${host}-vpn") (
      filterAttrs (host: v: v.config.${ns}.core.device.vpnAddress != null) self.nixosConfigurations
    );
in
{
  opts = with lib; {
    enableIPv6 = mkEnableOption "IPv6 DNS responses";
    debug = mkEnableOption "verbose logs for debugging";

    listenPort = mkOption {
      type = types.port;
      default = 53;
      description = "Listen port for DNS requests";
    };

    ctrldListenPort = mkOption {
      type = types.port;
      default = 5354;
      description = "Listen port for the internal Ctrld DNS server";
    };

    interfaces = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of additional interfaces for dnsmasq to be exposed on.
      '';
    };

    routerAddress = mkOption {
      type = types.str;
      default = null;
      description = ''
        Local IP address of the router that internal DDNS queries should be
        pointed to.
      '';
    };

    dnsmasqConfig = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Dnsmasq settings";
    };

    generateDnsmasqConfig = mkOption {
      type = types.functionTo (types.functionTo types.pathInStore);
      readOnly = true;
      description = "Internal function for generate dnsmasq config from attrset";
    };
  };

  asserts = [
    (device.type == "server")
    "DNS stack can only be used on server devices"
    (device.address != null)
    "The DNS stack requires the device to have a static IP address set"
    (cfg.routerAddress != "")
    "The DNS stack requires the device to have a router IP address set"
  ];

  users.users.ctrld = {
    group = "ctrld";
    isSystemUser = true;
  };
  users.groups.ctrld = { };

  systemd.services.ctrld =
    let
      # Patch Ctrld to enable loading endpoints from environment variables
      ctrld = addPatches pkgs.${ns}.ctrld [ "ctrld-secret-endpoint.patch" ];
      configFile = (pkgs.formats.toml { }).generate "ctrld.toml" settings;

      settings = {
        service = {
          log_level = if (cfg.debug || vmVariant) then "trace" else "notice";
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

        network."0" = {
          name = "Any Network";
          cidrs = [ "0.0.0.0/0" ];
        };

        listener."0" = {
          ip = "127.0.0.1";
          port = cfg.ctrldListenPort;
        };

        listener."0".policy = {
          name = "Failover DNS";
          networks = singleton {
            "network.0" = [
              "upstream.0"
              "upstream.1"
            ];
          };
        };

        upstream = {
          "0" = {
            name = "Control D Main Profile";
            # The actual endpoint is loaded from an environment variable
            endpoint = "https://dns.controld.com/secret";
            bootstrap_ip = "76.76.2.22";
            timeout = 3000;
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
    in
    {
      description = "Ctrld";
      after = [ "network.target" ];
      wantedBy = [ "dnsmasq.service" ];
      startLimitIntervalSec = 5;
      startLimitBurst = 10;

      serviceConfig = hardeningBaseline config {
        ExecStart = "${getExe ctrld} run --config ${configFile}";
        Restart = "always";
        RestartSec = 10;
        EnvironmentFile = config.age.secrets.ctrldEndpoint.path;

        # WARN: Running as a custom user breaks the ctrld 'controlServer'
        # because ctrld tries to write a socket file to /var/run. The
        # 'controlServer' provides the ctrld start, stop, reload etc...
        # commands. Since we are running ctrld in a systemd service we don't
        # need these anyway and would prefer the extra security.
        User = "ctrld";
        Group = "ctrld";

        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];

        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };
    };

  # The QUIC library that ctrld uses wants this https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };

  # Populate hosts file for ctrld host discovery
  networking.hosts = mapAttrs (_: v: [ v ]) homeHosts;

  # We don't use the upstream dnsmasq module because it isn't very good
  users.users.dnsmasq = {
    isSystemUser = true;
    group = "dnsmasq";
  };
  users.groups.dnsmasq = { };

  # Disable systemd-resolved to simplify DNS stack
  ns.system.networking.resolved.enable = mkForce false;

  ns.services.dns-stack = {
    dnsmasqConfig = {
      port = cfg.listenPort;
      log-queries = cfg.debug || vmVariant;

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
        # Point reverse proxy traffic to the device to avoid need for hairpin
        # NAT
        "/${fqDomain}/${device.address}"
        # Return NXDOMAIN for AAAA requests. Otherwise AAAA requests resolve to
        # the public DDNS CNAME response which resolves to public IP.
        "/${fqDomain}/"
        # Return NXDOMAIN for old fqDomain
        "/${oldFqDomain}/"
      ];

      # Host records create PTR entries as well. Using addn-hosts created
      # duplicate entries for some reason so using this instead.
      host-record = mapAttrsToList (address: hostname: "${hostname}.lan,${address}") homeHosts;
    };

    # Settings generation copied from nixpkgs under MIT license
    # https://github.com/NixOS/nixpkgs/blob/4cba8b53da471aea2ab2b0c1f30a81e7c451f4b6/COPYING
    generateDnsmasqConfig =
      let
        formatKeyValue =
          name: value:
          if value == true then
            name
          else if value == false then
            "# setting `${name}` explicitly set to false"
          else
            lib.generators.mkKeyValueDefault { } "=" name value;

        settingsFormat = pkgs.formats.keyValue {
          mkKeyValue = formatKeyValue;
          listsAsDuplicateKeys = true;
        };
      in
      name: settings: settingsFormat.generate name settings;
  };

  # Open DNS ports in firewall
  networking.firewall.allowedTCPPorts = [ cfg.listenPort ];
  networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
  networking.firewall.interfaces = (
    genAttrs cfg.interfaces (_: {
      allowedTCPPorts = [ cfg.listenPort ];
      allowedUDPPorts = [ cfg.listenPort ];
    })
  );

  # Set nameserver to localhost
  networking.nameservers = mkForce [ "127.0.0.1" ];
  networking.resolvconf.useLocalResolver = true;

  systemd.services.dnsmasq =
    let
      configFile = cfg.generateDnsmasqConfig "dnsmasq.conf" cfg.dnsmasqConfig;
      dnsmasq = getExe pkgs.dnsmasq;
      kill = getExe' pkgs.coreutils "kill";
    in
    {
      description = "Dnsmasq";
      after = [ "network.target" ];
      before = [ "nss-lookup.target" ];
      wants = [ "nss-lookup.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = hardeningBaseline config {
        ExecStartPre = "${dnsmasq} -C ${configFile} --test";
        ExecStart = "${dnsmasq} -k --user=dnsmasq -C ${configFile}";
        ExecReload = "${kill} -HUP $MAINPID";
        Restart = "always";

        DynamicUser = false;
        PrivateUsers = false;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_NETLINK"
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallFilter = [
          "@system-service"
          "~@resources"
        ];
        CapabilityBoundingSet = [
          "CAP_CHOWN"
          "CAP_SETUID"
          "CAP_SETGID"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        AmbientCapabilities = [
          "CAP_CHOWN"
          "CAP_SETUID"
          "CAP_SETGID"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        SocketBindDeny = "any";
        SocketBindAllow = cfg.listenPort;
      };
    };
}
