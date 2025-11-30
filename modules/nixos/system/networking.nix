{
  lib,
  cfg,
  args,
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
    elem
    listToAttrs
    toInt
    optional
    optionalAttrs
    imap0
    optionals
    mapAttrs
    optionalString
    attrNames
    hiPrio
    length
    getExe'
    getExe
    mkEnableOption
    mkOption
    types
    ;
  inherit (lib.${ns}) addPatches wrapHyprlandMoveToActive mkHyprlandCenterFloatRule;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) desktop;
  homeFirewall = config.${ns}.hmNs.firewall;
  rfkill = getExe' pkgs.util-linux "rfkill";
  ip = getExe' pkgs.iproute2 "ip";
  vlanIds = attrNames cfg.vlans;
  freq5GHzList = "5180 5200 5220 5240 5260 5280 5300 5320 5500 5520 5540 5560 5580 5600 5620 5640 5660 5680 5700 5720 5745 5765 5785 5805 5825";
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
    eduroam.enable = mkEnableOption "eduroam";

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

      backend = mkOption {
        type = types.enum [
          "iwd"
          "wpa_supplicant"
        ];
        default = "iwd";
        description = ''
          The wireless authentication backend to use. I've had issues with
          wpa_supplicant not working with specific Wifi-7 APs so iwd is the
          default.
        '';
      };

      force5GHzNetworks = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of wireless network SSIDs to force 5GHz by default. Can be
          toggled at runtime `toggle-force-5ghz`.
        '';
      };

      fallbackToWPA2 = mkEnableOption ''
        creating WPA2 fallback variants of wireless networks. Useful for
        devices that do not support WPA3.
      '';

      interface = mkOption {
        type = types.str;
        example = "wlp6s0";
      };

      disableOnBoot = mkEnableOption ''
        disabling of wireless on boot. Use `rfkill unblock wifi` to manually enable.
      '';

      powersave = mkOption {
        type = types.bool;
        default = config.${ns}.core.device.type == "laptop";
        description = "Whether to enable wireless power management";
      };
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

  nixpkgs.overlays = [
    (_: prev: {
      # Workaround to fix "ERROR:Failed to get interface "wlan0"" when resuming
      # from suspend/hibernate
      # https://gitlab.com/craftyguy/networkd-dispatcher/-/issues/55
      networkd-dispatcher = lib.${ns}.addPatches prev.networkd-dispatcher [
        "networkd-dispatcher-wait-for-interface.patch"
      ];

      wpa_supplicant = addPatches prev.wpa_supplicant [
        # We want to persist /etc/wpa_supplicant.conf with a bind mount but
        # wpa_supplicant renames a temporary file to modify the config. This
        # doesn't work with bind mounts due to "device or resource busy" error.
        # Patch works around this by copying file contents instead of renaming.
        # https://github.com/nix-community/impermanence/issues/175
        "wpa-supplicant-impermanence-config-rename.patch"
      ];
    })
  ];

  systemd.network = mkIf cfg.useNetworkd {
    enable = true;
    wait-online.anyInterface = true;

    # The default timeout of 120 seconds is too long for devices where we want
    # to get into the desktop regardless of network connectivity. This also
    # fixes an issue with UWSM. By default, the `uwsm check may-start` and
    # `uwsm start` commands hava a 60 second timeout waiting for
    # `graphical.target` before they give up. This caused our tty to get
    # dropped into an interactive shell where we had to manually start the UWSM
    # session.
    wait-online.timeout = mkIf desktop.enable 10;

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

    firewall = {
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
      enable = cfg.wireless.backend == "wpa_supplicant";
      userControlled.enable = true;
      secretsFile = config.age.secrets.wpaSupplicantSecrets.path;
      scanOnLowSignal = config.${ns}.core.device.type == "laptop";
      allowAuxiliaryImperativeNetworks = true;
      fallbackToWPA2 = cfg.wireless.fallbackToWPA2;
      networks = mapAttrs (
        ssid: network:
        network
        // {
          extraConfig = ''
            ${network.extraConfig or ""}
            ${optionalString (elem ssid cfg.wireless.force5GHzNetworks) "freq_list=${freq5GHzList}"}
          '';
        }
      ) (inputs.nix-resources.secrets.wpaSupplicantNetworks args);

      iwd = {
        enable = cfg.wireless.backend == "iwd";
        settings = {
          General.AddressRandomization = "network";
          # https://github.com/nixos/nixpkgs/issues/454655
          DriverQuirks.DefaultInterface = "";
        };
      };
    };
  };

  ns.persistence.directories = optional (cfg.wireless.enable && cfg.wireless.backend == "iwd") {
    directory = "/var/lib/iwd";
    mode = "0700";
  };

  systemd.services.iwd = mkIf (cfg.wireless.enable && cfg.wireless.backend == "iwd") {
    preStart = ''
      ${lib.concatMapStrings (network: ''
        cp --no-preserve=mode ${config.age.secrets."iwd-${network}".path} /var/lib/iwd/${network}
      '') inputs.nix-resources.secrets.iwdNetworks}
    '';
  };

  # To persist imperatively configured networks
  ns.persistence.files = optional (
    cfg.wireless.enable && cfg.wireless.backend == "wpa_supplicant"
  ) "/etc/wpa_supplicant.conf";

  services.resolved.enable = cfg.resolved.enable;

  ns.userPackages =
    optional (cfg.wireless.enable && cfg.wireless.backend == "wpa_supplicant") (
      pkgs.writeShellScriptBin "toggle-force-5ghz" ''
        net_id=$(wpa_cli -i "${cfg.wireless.interface}" list_networks | grep '\[CURRENT\]' | cut -f1)

        if [[ -z $net_id ]]; then
          wpa_cli -i "${cfg.wireless.interface}" list_networks
          read -p "Could not get active network. Enter a networkd id (e.g. 0): " -r net_id
        fi

        if [[ $(wpa_cli -i "${cfg.wireless.interface}" get_network "$net_id" freq_list) == "${freq5GHzList}" ]]; then
          wpa_cli -i "${cfg.wireless.interface}" set_network "$net_id" freq_list '""'
          echo "Disabled forcing 5Ghz"
        else
          wpa_cli -i "${cfg.wireless.interface}" set_network "$net_id" freq_list "${freq5GHzList}"
          echo "Enabled forcing 5Ghz"
        fi

        wpa_cli -i "${cfg.wireless.interface}" reassociate
      ''
    )
    ++ optionals (cfg.wireless.enable && cfg.wireless.backend == "wpa_supplicant" && desktop.enable) [
      # wpa_gui attempts to load the first interface it finds in
      # /var/run/wpa_supplicant. If this happens to be a p2p-dev-* interface,
      # wpa_gui goes into a fails with "Could not get status from
      # wpa_supplicant". Forcing the correct interface with -i fixes this.
      # (the -q flag disables the "running in tray" notification)
      (wrapHyprlandMoveToActive args pkgs.wpa_supplicant_gui "wpa_gui" ''
        --add-flags "-i ${cfg.wireless.interface} -q" \
        --run '
          if ${getExe' pkgs.procps "pidof"} wpa_gui > /dev/null; then
            ${getExe pkgs.libnotify} --urgency=critical -t 5000 "WPA GUI" "Application already running"
            exit 1
          fi
        '
      '')
      (hiPrio (
        pkgs.runCommand "wpa-supplicant-desktop-modify" { } ''
          mkdir -p $out/share/applications
          substitute ${pkgs.wpa_supplicant_gui}/share/applications/wpa_gui.desktop $out/share/applications/wpa_gui.desktop \
            --replace-fail "Name=wpa_gui" "Name=WPA GUI"
        ''
      ))
    ]
    ++ optional (cfg.wireless.enable && cfg.wireless.backend == "iwd") (
      wrapHyprlandMoveToActive args pkgs.impala "impala" ""
    );

  ns.hm = mkIf home-manager.enable {
    xdg.desktopEntries.impala =
      mkIf (cfg.wireless.enable && cfg.wireless.backend == "iwd" && desktop.enable)
        {
          name = "Impala";
          genericName = "Wifi Manager";
          exec = "xdg-terminal-exec --title=impala --app-id=impala impala";
          terminal = false;
          type = "Application";
          icon = "nm-device-wireless";
          categories = [ "System" ];
        };

    ${ns}.desktop.hyprland.windowRules = {
      wpa-gui = mkIf (cfg.wireless.enable && cfg.wireless.backend == "wpa_supplicant" && desktop.enable) (
        mkHyprlandCenterFloatRule "wpa_gui" 40 60
      );
      impala = mkIf (cfg.wireless.enable && cfg.wireless.backend == "iwd" && desktop.enable) (
        mkHyprlandCenterFloatRule "impala" 60 60
      );
    };
  };

  systemd.services.disable-wifi-on-boot = mkIf (cfg.wireless.enable && cfg.wireless.disableOnBoot) {
    description = "Disable wifi on boot";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rfkill} block wifi";
    };
  };

  systemd.services.disable-wifi-powersave = mkIf (cfg.wireless.enable && !cfg.wireless.powersave) {
    description = "Disable wifi powersave";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${getExe pkgs.iw} dev ${cfg.wireless.interface} set power_save off";
    };
  };

  programs.zsh = {
    shellAliases = mkMerge [
      (mkIf cfg.wireless.enable {
        wifi-up = "sudo ${rfkill} unblock wifi";
        wifi-down = "sudo ${rfkill} block wifi";
      })

      (mkIf (cfg.wiredInterface != null) {
        ethernet-up = "sudo ${ip} link set ${cfg.wiredInterface} up";
        ethernet-down = "sudo ${ip} link set ${cfg.wiredInterface} down";
      })
    ];

    interactiveShellInit = # bash
      ''
        open-captive-portal() {
          echo "May have to manually switch DNS servers to the public wifi's DNS with \`resolvectl dns <interface> <dns_ip>\`"
          echo "Remember to turn off VPNs"
          echo "Opening 'http://captive.apple.com' in an attempt to force a captive portal redirect..."
          xdg-open http://captive.apple.com >/dev/null
        }
      '';
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
