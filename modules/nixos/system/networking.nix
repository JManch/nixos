{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  hostname,
}:
let
  inherit (lib)
    ns
    mkMerge
    mkIf
    listToAttrs
    toInt
    optional
    optionalAttrs
    imap0
    optionals
    attrNames
    hiPrio
    length
    getExe'
    mkEnableOption
    mkOption
    types
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) desktop;
  homeFirewall = config.${ns}.hmNs.firewall;
  rfkill = getExe' pkgs.util-linux "rfkill";
  ip = getExe' pkgs.iproute2 "ip";
  vlanIds = attrNames cfg.vlans;
in
{
  enableOpt = false;

  opts = {
    useNetworkd =
      mkEnableOption ''
        Whether to enable systemd-networkd network configuration.
      ''
      // {
        default = true;
      };

    tcpOptimisations = mkEnableOption "TCP optimisations";
    resolved.enable = mkEnableOption "Resolved";

    wiredInterface = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "enp5s0";
      description = ''
        Wired network interface of the device. Be careful to use the main
        interface name displayed in `ip a`, NOT the altname.
      '';
    };

    staticIPAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Disable DHCP and assign the device a static IPV4 address. Remember to
        include the network's subnet mask.
      '';
    };

    defaultGateway = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Default gateway of the device's primary local network.
      '';
    };

    wireless = {
      enable = mkEnableOption "wireless";

      onlyWpa2 = mkEnableOption ''
        only configuring WPA2 networks for devices that do not support WPA3
      '';

      interface = mkOption {
        type = types.str;
        example = "wlp6s0";
      };

      disableOnBoot = mkEnableOption ''
        disabling of wireless on boot. Use `rfkill unblock wifi` to manually enable.
      '';
    };

    firewall = {
      enable = mkEnableOption "Firewall" // {
        default = true;
      };

      defaultInterfaces = mkOption {
        type = types.listOf types.str;
        default = optional (cfg.wiredInterface != null) cfg.wiredInterface;
        example = [
          "eno1"
          "wlp6s0"
        ];
        description = ''
          List of interfaces to which default firewall rules should be applied.
        '';
      };
    };

    vlans = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = ''
        Attribute set where the keys are VLAN IDs and the values are the
        VLAN's network config. The VLANs will the added to the primary
        interface.
      '';
    };
  };

  asserts = [
    (cfg.staticIPAddress != null -> cfg.defaultGateway != null)
    "Default gateway must be set when using a static IPV4 address"
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
        "10-wired" = mkIf (cfg.wiredInterface != null) {
          matchConfig.Name = cfg.wiredInterface;

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
      // (optionalAttrs home-manager.enable {
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
      secretsFile = config.age.secrets.wirelessNetworks.path;
      scanOnLowSignal = config.${ns}.core.device.type == "laptop";
      allowAuxiliaryImperativeNetworks = true;

      networks = {
        # Use psk for WPA3 and pskRaw for WPA2. More info in secret file.
        # Priorities seem to get assigned for 2.4GHz and 5GHz so increment by 2
        # between each network

        # Inspect the generated file at /run/wpa_supplicant/wpa_supplicant.conf
        # Manually reload config with `wpa_cli -i <wireless_interface> reconfigure`
        Mikrotik = mkIf (!cfg.wireless.onlyWpa2) {
          pskRaw = "ext:MIKROTIK";
          priority = 3;
        };

        Mikrotik-Guest = mkIf cfg.wireless.onlyWpa2 {
          pskRaw = "ext:MIKROTIK_GUEST";
          priority = 3;
        };

        "Pixel 5" = {
          pskRaw = "ext:PIXEL_5";
          priority = 1;
        };
      };
    };
  };

  services.resolved.enable = cfg.resolved.enable;

  ns.userPackages = optionals (cfg.wireless.enable && desktop.enable) [
    pkgs.wpa_supplicant_gui
    (hiPrio (
      pkgs.runCommand "wpa-supplicant-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.wpa_supplicant_gui}/share/applications/wpa_gui.desktop $out/share/applications/wpa_gui.desktop \
          --replace-fail "Name=wpa_gui" "Name=WPA GUI"
      ''
    ))
  ];
  systemd.services.wpa_supplicant.preStart = "${getExe' pkgs.coreutils "touch"} /etc/wpa_supplicant.conf";

  systemd.services.disable-wifi-on-boot = mkIf (cfg.wireless.enable && cfg.wireless.disableOnBoot) {
    restartIfChanged = false;
    description = "Disable wifi on boot";
    after = [ "systemd-networkd.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rfkill} block wifi";
      RemainAfterExit = true;
    };
  };

  programs.zsh.shellAliases = mkMerge [
    (mkIf cfg.wireless.enable {
      wifi-up = "sudo ${rfkill} unblock wifi";
      wifi-down = "sudo ${rfkill} block wifi";
    })

    (mkIf (cfg.wiredInterface != null) {
      ethernet-up = "sudo ${ip} link set ${cfg.wiredInterface} up";
      ethernet-down = "sudo ${ip} link set ${cfg.wiredInterface} down";
    })
  ];

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
