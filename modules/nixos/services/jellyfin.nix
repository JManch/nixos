{ lib
, config
, inputs
, username
, ...
}:
let
  inherit (lib) mkIf utils mkMerge optional mkForce optionalString;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.services) caddy wireguard;
  inherit (config.services) jellyfin;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.jellyfin;
in
mkMerge [
  (mkIf cfg.enable
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      systemd.services.jellyfin = {
        wantedBy = mkForce (optional cfg.autoStart [ "multi-user.target" ]);

        serviceConfig = {
          # Bind mount home media directories so jellyfin can access them
          BindReadOnlyPaths = [
            "/home/${username}/videos/shows:/var/lib/jellyfin/media/shows"
            "/home/${username}/videos/movies:/var/lib/jellyfin/media/movies"
          ];
          SocketBindDeny = publicPorts;
        };
      };

      # Jellyfin module has good default hardening

      systemd.tmpfiles.rules = [
        "d /var/lib/jellyfin/media/shows 700 ${jellyfin.user} ${jellyfin.group}"
        "d /var/lib/jellyfin/media/movies 700 ${jellyfin.user} ${jellyfin.group}"
      ];

      persistence.directories = [{
        directory = "/var/lib/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "700";
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
      abort @block
      reverse_proxy http://${cfg.reverseProxy.address}:8096
    '';
  })
]
