{ lib, config, username, ... }:
let
  inherit (lib) mkIf optional mkForce;
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
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/jellyfin/media/shows 755 root root"
    "d /var/lib/jellyfin/media/movies 755 root root"
  ];

  persistence.directories = [ "/var/lib/jellyfin" ];
}
