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
    attrValues
    mapAttrsToList
    optionalString
    singleton
    length
    hasPrefix
    splitString
    all
    ;
  inherit (lib.${ns}) asserts;
  inherit (config.${ns}.system) impermanence;
  inherit (config.${ns}.services) caddy torrent-stack;
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
      (all (n: !hasPrefix "/persist" n) (attrValues cfg.mediaDirs))
      "Jellyfin media dirs should NOT be prefixed with /persist"
    ];

    services.jellyfin = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    users.users.jellyfin.uid = uid;
    users.groups.jellyfin.gid = gid;

    systemd.services.jellyfin.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");

    systemd.mounts = mapAttrsToList (target: source: {
      what = (optionalString impermanence.enable "/persist") + source;
      where = "/var/lib/jellyfin/media/${target}";
      bindsTo = [ "jellyfin.service" ];
      requiredBy = [ "jellyfin.service" ];
      before = [ "jellyfin.service" ];
      options = "bind,ro";
      mountConfig.DirectoryMode = "0700";
    }) cfg.mediaDirs;

    systemd.tmpfiles.rules = [
      "d /var/lib/jellyfin/media 0700 jellyfin jellyfin - -"
    ];

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

  (mkIf cfg.jellyseerr.enable {
    assertions = asserts [
      (cfg.enable && torrent-stack.enable)
      "Jellyseerr requires Jellyfin and the Torrent stack to be enabled"
    ];

    users.groups.jellyseerr = { };
    users.users.jellyseerr = {
      group = "jellyseerr";
      isSystemUser = true;
    };

    services.jellyseerr = {
      enable = jellyfin.enable;
      openFirewall = false;
      port = cfg.jellyseerr.port;
    };

    systemd.services.jellyseerr = {
      serviceConfig = {
        User = "jellyseerr";
        Group = "jellyseerr";
        SupplementaryGroups = [ "media" ];
      };
    };

    ${ns}.services.caddy.virtualHosts.jellyseerr.extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.jellyseerr.port}
    '';

    persistence.directories = singleton {
      directory = "/var/lib/private/jellyseerr";
      user = "jellyseerr";
      group = "jellyseerr";
      mode = "0750";
    };
  })
]
