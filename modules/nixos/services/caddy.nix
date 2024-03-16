{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mapAttrs getExe concatStringsSep mkVMOverride;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.system.virtualisation) vmVariant;
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

    virtualHosts."logs.${fqDomain}".extraConfig = ''
      import lan_only
      root * /var/lib/goaccess/
      file_server * browse

      @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
      }
      reverse_proxy @websockets http://127.0.0.1:7890
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
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RemoveIPC = true;
    RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SocketBindDeny = "any";
    SocketBindAllow = [ 443 80 ];
    MemoryDenyWriteExecute = true;
  };

  systemd.services.goaccess =
    let
      runGoAccess = pkgs.writeShellScript "run-caddy-goaccess" ''
        # Get list of all caddy access logs
        logs=""
        # shellcheck disable=SC2044
        for file in $(${getExe pkgs.findutils} "/var/log/caddy" -type f -name "*.${fqDomain}.log"); do
          logs+=" $file"
        done

        exec ${getExe pkgs.goaccess} $logs \
          --log-format=CADDY \
          --real-time-html \
          --ws-url=logs.${fqDomain}:${if vmVariant then "50080" else "443"} \
          --port=7890 \
          --real-os \
          -o /var/lib/goaccess/index.html
      '';
    in
    {
      unitConfig = {
        Description = "GoAccess log analyzer";
        PartOf = [ "caddy.service" ];
        After = [ "caddy.service" "network.target" ];
      };

      serviceConfig = {
        # TODO: Might want to exclude private ip ranges
        ExecStart = "${runGoAccess.outPath}";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "caddy";
        Group = "caddy";

        StateDirectory = [ "goaccess" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectClock = true;
        ProtectHostname = true;
        ProtectProc = "invisible";
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SocketBindDeny = publicPorts;
        MemoryDenyWriteExecute = true;
      };

      wantedBy = [ "multi-user.target" ];
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

      # Prefix every hostname with http://
      virtualHosts = mkVMOverride (
        mapAttrs (_: value: value // { hostName = ("http://" + value.hostName); }) config.services.caddy.virtualHosts
      );
    };
  };
}
