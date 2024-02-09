{ lib, config, username, ... }:
let
  cfg = config.modules.services.jellyfin;
in
lib.mkIf cfg.enable
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.jellyfin = {
    wantedBy = lib.mkForce (lib.lists.optional cfg.autoStart [ "multi-user.target" ]);
    # Bind mount home media directories so jellyfin can access them
    serviceConfig = {
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

  environment.persistence."/persist".directories = [
    "/var/lib/jellyfin"
  ];
}
