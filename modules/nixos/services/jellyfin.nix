# WARN: It's important to close the webpage when casting from Jellyfin to
# external clients such as jellyfin-mpv-shim or a TV. This is because the
# Jellyfin client that started the cast will request a large chunk of metadata
# every couple of seconds (presumably to update the cast progress bar?). With
# multiple clients watching this can easily throttle the web server and make
# Jellyfin unusable.
{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    optional
    mkForce
    genAttrs
    ;
  inherit (config.${ns}.system.networking) publicPorts;
  inherit (config.${ns}.services) caddy;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.services) jellyfin;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.${ns}.services.jellyfin;
  uid = 1500;
  gid = 1500;
in
mkMerge [
  {
    ${ns}.system.reservedIDs.jellyfin = {
      inherit uid gid;
    };
  }

  (mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    users.users.jellyfin.uid = uid;
    users.groups.jellyfin.gid = gid;

    systemd.services.jellyfin = {
      wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
      serviceConfig.SocketBindDeny = publicPorts;
    };

    networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
      allowedTCPPorts = [
        8096
        8920
      ];
      allowedUDPPorts = [
        1900
        7359
      ];
    });

    # Jellyfin module has good default hardening

    backups.jellyfin = {
      paths = [ "/var/lib/jellyfin" ];
      exclude = [
        "transcodes"
        "media"
        "log"
        "metadata"
      ];
      restore = {
        preRestoreScript = "sudo systemctl stop jellyfin";
        pathOwnership = {
          "/var/lib/jellyfin" = {
            user = "jellyfin";
            group = "jellyfin";
          };
        };
      };
    };

    persistence.directories = [
      {
        directory = "/var/lib/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "700";
      }
      {
        directory = "/var/cache/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "700";
      }
    ];
  })

  (mkIf cfg.reverseProxy.enable {
    assertions = lib.${ns}.asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    services.caddy.virtualHosts."jellyfin.${fqDomain}".extraConfig = ''
      ${allowAddresses (trustedAddresses ++ cfg.allowedAddresses)}
      reverse_proxy http://${cfg.reverseProxy.address}:8096
    '';
  })
]
