{
  lib,
  pkgs,
  config,
  inputs,
  username,
  hostname,
  ...
}:
let
  inherit (lib)
    mkMerge
    mkIf
    utils
    listToAttrs
    toInt
    optional
    optionalAttrs
    imap0
    attrNames
    length
    getExe'
    allUnique
    ;
  inherit (config.modules.core) homeManager;
  cfg = config.modules.system.networking;
  homeFirewall = config.home-manager.users.${username}.firewall;
  rfkill = getExe' pkgs.util-linux "rfkill";
  vlanIds = attrNames cfg.vlans;
in
{
  assertions = utils.asserts [
    (cfg.primaryInterface != null)
    "Primary networking interface must be set"
    ((cfg.staticIPAddress != null) -> (cfg.defaultGateway != null))
    "Default gateway must be set when using a static IPV4 address"
    (allUnique cfg.publicPorts)
    "`networking.publicPorts` contains duplicate ports"
    (vlanIds != [ ] -> cfg.useNetworkd)
    "VLAN config only works with networkd"
    (length vlanIds <= 10)
    "A single interface cannot have more than 10 VLANs assigned (arbitrary limit because of VLAN name mapping)"
  ];

  systemd.network = mkIf cfg.useNetworkd {
    enable = true;
    wait-online.anyInterface = true;

    # Nix generates default systemd-networkd network configs which match all
    # interfaces so manually defining networks is not really necessary unless
    # custom configuration is required
    networks = mkIf (!inputs.vmInstall.value) (
      {
        # TODO: Might want to bond wired and wireless networks
        "10-wired" = {
          matchConfig.Name = cfg.primaryInterface;

          networkConfig = {
            DHCP = cfg.staticIPAddress == null;
            Address = mkIf (cfg.staticIPAddress != null) cfg.staticIPAddress;
            Gateway = mkIf (cfg.staticIPAddress != null) cfg.defaultGateway;
            VLAN = map (vlanId: "vlan${vlanId}") vlanIds;
          };

          dhcpV4Config.ClientIdentifier = "mac";
        };

        "10-wireless" = mkIf cfg.wireless.enable {
          matchConfig.Name = cfg.wireless.interface;
          networkConfig.DHCP = true;
          dhcpV4Config.RouteMetric = 1025;
        };
      }
      // listToAttrs (
        imap0 (i: vlanId: {
          name = "2${toString i}-vlan${vlanId}";
          value = {
            matchConfig = {
              Name = "vlan${vlanId}";
              Type = "vlan";
            };
            networkConfig = cfg.vlans.${vlanId};
            dhcpV4Config.ClientIdentifier = "mac";
          };
        }) vlanIds
      )
    );

    # Useful VLAN guide:
    # https://volatilesystems.org/implementing-vlans-with-systemd-networkd-on-an-active-physical-interface.html
    # https://archive.ph/t6bJg

    # Netdevs have to be defined before physical interfaces
    netdevs = listToAttrs (
      imap0 (i: vlanId: {
        name = "${toString i}-vlan${vlanId}";
        value = {
          netdevConfig = {
            Name = "vlan${vlanId}";
            Kind = "vlan";
          };
          vlanConfig.Id = toInt vlanId;
        };
      }) vlanIds
    );
  };

  networking = {
    hostName = hostname;
    useNetworkd = cfg.useNetworkd;

    firewall =
      {
        enable = cfg.firewall.enable;
        defaultInterfaces = cfg.firewall.defaultInterfaces;
      }
      // (optionalAttrs homeManager.enable {
        inherit (homeFirewall)
          allowedTCPPorts
          allowedTCPPortRanges
          allowedUDPPorts
          allowedUDPPortRanges
          interfaces
          ;
      });

    wireless = mkIf cfg.wireless.enable {
      enable = true;
      userControlled.enable = true;
      environmentFile = config.age.secrets.wirelessNetworks.path;
      scanOnLowSignal = config.device.type == "laptop";
      allowAuxiliaryImperativeNetworks = true;

      networks = {
        "Pixel 5" = {
          pskRaw = "@PIXEL_5@";
        };
      };
    };
  };

  services.resolved.enable = cfg.resolved.enable;

  userPackages = optional cfg.wireless.enable pkgs.wpa_supplicant_gui;
  systemd.services.wpa_supplicant.preStart = "${getExe' pkgs.coreutils "touch"} /etc/wpa_supplicant.conf";

  systemd.services."disable-wifi-on-boot" = mkIf (cfg.wireless.enable && cfg.wireless.disableOnBoot) {
    restartIfChanged = false;

    unitConfig = {
      Description = "Disable wireless interface on boot";
      After = [ "systemd-networkd.service" ];
    };

    serviceConfig = {
      ExecStart = "${rfkill} block wifi";
      Type = "oneshot";
      RemainAfterExit = true;
    };

    wantedBy = [ "multi-user.target" ];
  };

  programs.zsh.shellAliases =
    let
      ip = getExe' pkgs.iproute2 "ip";
    in
    {
      "wifi-up" = "sudo ${rfkill} unblock wifi";
      "wifi-down" = "sudo ${rfkill} block wifi";
      "ethernet-up" = "sudo ${ip} link set ${cfg.primaryInterface} up";
      "ethernet-down" = "sudo ${ip} link set ${cfg.primaryInterface} down";
    };

  boot = {
    kernelModules = optional cfg.tcpOptimisations "tcp_bbr";

    kernel.sysctl = mkMerge [
      {
        "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
        # Enable reverse path filtering
        "net.ipv4.conf.default.rp_filter" = 1;
        "net.ipv4.conf.all.rp_filter" = 1;
        # Do not accept IP source route packets
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        # Don't send ICMP redirects
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
        # Refuse ICMP redirects
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.secure_redirects" = 0;
        "net.ipv4.conf.default.secure_redirects" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;
        # Protects against SYN flood attacks
        "net.ipv4.tcp_syncookies" = 1;
        # Incomplete protection again TIME-WAIT assassination
        "net.ipv4.tcp_rfc1337" = 1;
      }

      (mkIf cfg.tcpOptimisations {
        # Enables data to be exchanged during the initial TCP SYN
        "net.ipv4.tcp_fastopen" = 3;
        # Theoretical higher bandwidth + lower latency
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "cake";
      })
    ];
  };
}
