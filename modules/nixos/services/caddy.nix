{ lib, config, ... }:
let
  inherit (lib) mkIf concatStringsSep;
  cfg = config.modules.services.caddy;
in
mkIf cfg.enable
{
  services.caddy = {
    enable = true;
    # Does not work when the admin API is off
    enableReload = false;

    globalConfig = ''
      admin off
    '';

    extraConfig = ''

      (lan_only) {
        @block {
          not remote_ip ${concatStringsSep " " cfg.lanAddressRanges}
        }
        respond @block "Access denied" 403 {
          close
        }
      }

    '';
  };

  networking.firewall.allowedTCPPorts = [ 443 80 ];
  networking.firewall.allowedUDPPorts = [ 443 ];
  modules.system.networking.publicPorts = [ 443 80 ];

  # Extra hardening
  systemd.services.caddy.serviceConfig = {
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RemoveIPC = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SocketBindDeny = "any";
    SocketBindAllow = [ 443 80 ];
    MemoryDenyWriteExecute = true;
  };

  persistence.directories =
    let
      inherit (config.services) caddy;
      definition = dir: {
        directory = dir;
        user = caddy.user;
        group = caddy.group;
        mode = "700";
      };
    in
    [
      (definition "/var/lib/caddy")
      (definition "/var/log/caddy")
    ];

  virtualisation.vmVariant = {
    modules.services.caddy.lanAddressRanges = [ "10.0.2.2/32" ];

    services.caddy = {
      # Confusingly auto_https off doesn't actually server all hosts of http
      # Each virtualhost needs to explicity specify http://
      # https://caddy.community/t/making-sense-of-auto-https-and-why-disabling-it-still-serves-https-instead-of-http/9761
      globalConfig = ''
        debug
        auto_https off
      '';
    };
  };
}
