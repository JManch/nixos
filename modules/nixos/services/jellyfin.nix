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
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    optional
    mkForce
    genAttrs
    attrNames
    mapAttrsToList
    length
    splitString
    all
    ;
  inherit (lib.${ns}) asserts;
  inherit (config.${ns}.system.networking) publicPorts;
  inherit (config.${ns}.services) caddy;
  inherit (config.services) jellyfin;
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
    assertions = asserts [
      (all (n: n != "") (attrNames cfg.mediaDirs))
      "Jellyfin media dir target cannot be empty"
      (all (n: (length (splitString "/" n)) == 1) (attrNames cfg.mediaDirs))
      "Jellyfin media dir target cannot be a subdir"
    ];

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

    systemd.mounts = mapAttrsToList (target: source: {
      what = source;
      where = "/var/lib/jellyfin/media/${target}";
      bindsTo = [ "jellyfin.service" ];
      requiredBy = [ "jellyfin.service" ];
      before = [ "jellyfin.service" ];
      options = "bind,ro";
      mountConfig.DirectoryMode = "0700";
    }) cfg.mediaDirs;

    systemd.tmpfiles.rules =
      [
        "d /var/lib/jellyfin/media 0700 jellyfin jellyfin - -"
      ]
      ++ mapAttrsToList (
        target: _: "d /var/lib/jellyfin/media/${target} 0700 jellyfin jellyfin - -"
      ) cfg.mediaDirs;

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

    backups.jellyfin = mkIf cfg.backup {
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
        mode = "0700";
      }
      {
        directory = "/var/cache/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "0700";
      }
    ];
  })

  (mkIf cfg.reverseProxy.enable {
    assertions = asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    ${ns}.services.caddy.virtualHosts.jellyfin = {
      inherit (cfg.reverseProxy) extraAllowedAddresses;
      extraConfig = ''
        reverse_proxy http://${cfg.reverseProxy.address}:8096
      '';
    };
  })
]
