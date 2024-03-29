{ lib, config, username, ... }:
let
  inherit (lib) mkIf optional mkForce;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.services) jellyfin;
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
