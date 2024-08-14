# WARN: It's important to close the webpage when casting from Jellyfin to
# external clients such as jellyfin-mpv-shim or a TV. This is because the
# Jellyfin client that started the cast will request a large chunk of metadata
# every couple of seconds (presumably to update the cast progress bar?). With
# multiple clients watching this can easily throttle the web server and make
# Jellyfin unusable.
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkMerge
    optional
    mkForce
    optionalString
    mapAttrsToList
    genAttrs
    attrNames
    ;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.services) caddy wireguard;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.services) jellyfin;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.jellyfin;
  uid = 1500;
  gid = 1500;
in
mkMerge [
  {
    modules.system.reservedIDs.jellyfin = {
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

      serviceConfig = {
        # Bind mount home media directories so jellyfin can access them
        BindReadOnlyPaths = mapAttrsToList (
          name: dir: "${dir}:/var/lib/jellyfin/media${optionalString (name != "") "/${name}"}"
        ) cfg.mediaDirs;
        SocketBindDeny = publicPorts;
      };
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

    systemd.tmpfiles.rules =
      [ "d /var/lib/jellyfin/media 0700 ${jellyfin.user} ${jellyfin.group}" ]
      ++ map (
        name:
        "d /var/lib/jellyfin/media${
          optionalString (name != "") "/${name}"
        } 0700 ${jellyfin.user} ${jellyfin.group}"
      ) (attrNames cfg.mediaDirs);

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
    assertions = utils.asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    services.caddy.virtualHosts."jellyfin.${fqDomain}".extraConfig =
      let
        addressRange = toString wireguard.friends.address + "/" + toString wireguard.friends.subnet;
        wgAddresses = optional wireguard.friends.enable addressRange;
      in
      ''
        ${allowAddresses (trustedAddresses ++ wgAddresses ++ cfg.extraAllowedAddresses)}
        reverse_proxy http://${cfg.reverseProxy.address}:8096
      '';
  })
]
