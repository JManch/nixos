{ lib, config, username, ... }:
let
  inherit (lib) mkIf optional mkForce;
  inherit (config.modules.system.networking) publicPorts;
  cfg = config.modules.services.jellyfin;
in
mkIf cfg.enable
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

  systemd.tmpfiles.rules = [
    "d /var/lib/jellyfin/media/shows 700 jellyfin jellyfin"
    "d /var/lib/jellyfin/media/movies 700 jellyfin jellyfin"
  ];

  persistence.directories = [ "/var/lib/jellyfin" ];
}
