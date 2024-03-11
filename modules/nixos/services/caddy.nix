{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf concatStringsSep;
  cfg = config.modules.services.caddy;
in
mkIf cfg.enable
{
  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      {
        admin off
      }

      (lan_only) {
        @block {
          not remote_ip ${concatStringsSep " " cfg.lanAddressRanges}
        }
        respond @block "Access denied" 403 {
          close
        }
      }

      (log) {
        log {
          output file /var/log/caddy/access.log
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

  persistence.directories = [
    "/var/lib/caddy"
    "/var/log/caddy"
  ];
}
