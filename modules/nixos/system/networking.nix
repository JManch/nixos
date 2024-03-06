{ lib
, pkgs
, config
, username
, hostname
, ...
} @ args:
let
  inherit (lib) mkMerge mkIf utils optional optionals getExe' mkDefault;
  cfg = config.modules.system.networking;
  homeManagerFirewall = (utils.homeConfig args).firewall;
in
{
  environment.systemPackages = with pkgs; [
    ifmetric # for changing metric in emergencies
  ] ++ optional cfg.wireless.enable wpa_supplicant_gui;

  users.users.${username}.extraGroups = [ "networkmanager" ];
  age.secrets.wirelessNetworks.file = ../../../secrets/wireless-networks.age;

  systemd.services.wpa_supplicant.preStart = "${getExe' pkgs.coreutils "touch"} /etc/wpa_supplicant.conf";
  services.resolved.enable = cfg.resolved.enable;

  networking = {
    hostName = hostname;
    useDHCP = mkDefault true;

    networkmanager = {
      enable = true;
      wifi.powersave = true;

      # Tell network manager not to manage wireless interfaces
      unmanaged = optionals cfg.wireless.enable [
        "*"
        "except:type:wwan"
        "except:type:gsm"
      ];
    };

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

    wireless = {
      enable = cfg.wireless.enable;
      environmentFile = config.age.secrets.wirelessNetworks.path;
      scanOnLowSignal = config.device.type == "laptop";
      # Allow imperative network config
      allowAuxiliaryImperativeNetworks = true;

      networks = {
        "Pixel 5" = {
          pskRaw = "@PIXEL_5@";
        };
      };

      userControlled = {
        enable = true;
        group = "networkmanager";
      };
    };

    dhcpcd = {
      enable = true;
      # Make Pixel 5 hotspot take priority over any other active network.
      # Useful in situations where the ethernet network goes down and hotspot
      # is used as a backup, but the device still prioritises the broken
      # ethernet network because of its lower metric.
      extraConfig = ''
        ssid Pixel 5
        metric 100
      '';
    };
  };

  systemd.services."disable-wifi-on-boot" = mkIf
    (cfg.wireless.enable && cfg.wireless.disableOnBoot)
    {
      unitConfig = {
        RestartIfChanged = false;
        Description = "Disable wireless interface on boot";
        After = [ "NetworkManager.service" ];
      };

      serviceConfig = {
        ExecStart = "${getExe' pkgs.util-linux "rfkill"} block wifi";
        Type = "oneshot";
        RemainAfterExit = "true";
      };

      wantedBy = [ "multi-user.target" ];
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
