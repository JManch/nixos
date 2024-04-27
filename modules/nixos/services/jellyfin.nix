{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkMerge
    optional
    mkForce
    optionalString
    mapAttrs
    attrValues
    attrNames;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.services) caddy wireguard;
  inherit (config.services) jellyfin;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.jellyfin;
in
mkMerge [
  (mkIf cfg.enable
    {
      environment.systemPackages = optional cfg.mediaPlayer pkgs.jellyfin-media-player;

      services.jellyfin = {
        enable = true;
        openFirewall = cfg.openFirewall;
      };

      users.users.jellyfin.uid = 997;
      users.groups.jellyfin.gid = 996;

      systemd.services.jellyfin = {
        wantedBy = mkForce (optional cfg.autoStart "multi-user.target");

        serviceConfig = {
          # Bind mount home media directories so jellyfin can access them
          BindReadOnlyPaths = attrValues
            (mapAttrs
              (name: dir: "${dir}:/var/lib/jellyfin/media${optionalString (name != "") "/${name}"}")
              cfg.mediaDirs);
          SocketBindDeny = publicPorts;
        };
      };

      networking.firewall.interfaces.wg-friends = mkIf (cfg.openFirewall && wireguard.friends.enable) {
        allowedTCPPorts = [ 8096 8920 ];
        allowedUDPPorts = [ 1900 7359 ];
      };

      # Jellyfin module has good default hardening

      systemd.tmpfiles.rules = map
        (name: "d /var/lib/jellyfin/media${optionalString (name != "") "/${name}"} 700 ${jellyfin.user} ${jellyfin.group}")
        (attrNames cfg.mediaDirs);

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

      persistenceHome.directories = mkIf cfg.mediaPlayer [
        ".local/share/Jellyfin Media Player"
        ".local/share/jellyfinmediaplayer"
      ];

      modules.services.nfs.client.fileSystems = [{
        path = "jellyfin";
        machine = "homelab.lan";
        user = jellyfin.user;
        group = jellyfin.group;
      }];
    }
  )

  (mkIf cfg.reverseProxy.enable {
    assertions = utils.asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    services.caddy.virtualHosts."jellyfin.${fqDomain}".extraConfig = ''
      @block {
        not remote_ip ${caddy.lanAddressRanges}${optionalString wireguard.friends.enable " ${wireguard.friends.address}/${toString wireguard.friends.subnet}"}
      }
      respond @block "Access denied" 403 {
        close
      }
      reverse_proxy http://${cfg.reverseProxy.address}:8096
    '';
  })
]
