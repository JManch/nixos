{ lib
, pkgs
, config
, hostname
, ...
} @ args:
let
  inherit (lib)
    mkMerge
    mkIf
    utils
    optional
    getExe'
    allUnique;
  cfg = config.modules.system.networking;
  homeManagerFirewall = (utils.homeConfig args).firewall;
  rfkill = getExe' pkgs.util-linux "rfkill";
in
{
  assertions = utils.asserts [
    (cfg.primaryInterface != null)
    "Primary networking interface must be set"
    ((cfg.staticIPAddress != null) -> (cfg.defaultGateway != null))
    "Default gateway must be set when using a static IPV4 address"
    (allUnique cfg.publicPorts)
    "`networking.publicPorts` contains duplicate ports"
  ];

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    # Nix generates default systemd-networkd network configs which match all
    # interfaces so manually defining networks is not really necessary unless
    # custom configuration is required
    networks = {
      # TODO: Might want to bond wired and wireless networks
      "10-wired" = {
        matchConfig.Name = cfg.primaryInterface;

        networkConfig = {
          DHCP = cfg.staticIPAddress == null;
          Address = mkIf (cfg.staticIPAddress != null) cfg.staticIPAddress;
          Gateway = mkIf (cfg.staticIPAddress != null) cfg.defaultGateway;
        };

        dhcpV4Config.ClientIdentifier = "mac";
      };

      "10-wireless" = mkIf cfg.wireless.enable {
        matchConfig.Name = cfg.wireless.interface;
        networkConfig.DHCP = true;
        dhcpV4Config.RouteMetric = 1025;
      };
    };
  };

  networking = {
    hostName = hostname;
    useNetworkd = true;

    firewall = {
      enable = cfg.firewall.enable;
      defaultInterfaces = cfg.firewall.defaultInterfaces;
      inherit (homeManagerFirewall)
        allowedTCPPorts
        allowedTCPPortRanges
        allowedUDPPorts
        allowedUDPPortRanges
        interfaces;
    };

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

  environment.systemPackages = optional cfg.wireless.enable pkgs.wpa_supplicant_gui;
  systemd.services.wpa_supplicant.preStart = "${getExe' pkgs.coreutils "touch"} /etc/wpa_supplicant.conf";

  systemd.services."disable-wifi-on-boot" = mkIf
    (cfg.wireless.enable && cfg.wireless.disableOnBoot)
    {
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
