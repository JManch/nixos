# How to modify starred at / favourited dates
# - Stop navidrome service
# - Mount navidrome state dir with sshfs
# - Open database file in sqlitebrowser
# - Copy item_id for album/track from either album or media_file table
# - In 'Execute SQL' tab run:
#   SELECT starred_at FROM annotation WHERE item_id = '<item_id>';
# - Copy the starred_at timestamps and modify it (timestamps can't be copied from tables for some reason)
# - Update data with:
#   UPDATE annotation SET starred_at = '<new_starred_at>' WHERE item_id = '<item_id>';
# - Press 'Write Changes'
{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns;
  inherit (config.${ns}.hardware.file-system) mediaDir;
  inherit (config.age.secrets) navidromeVars;
  musicDir = mediaDir + "/music";
in
{
  requirements = [ "services.caddy" ];

  services.navidrome = {
    enable = true;
    openFirewall = false;
    package = lib.${ns}.addPatches pkgs.navidrome [ "navidrome-lastfm-apostrophe.patch" ];

    settings = {
      Address = "127.0.0.1";
      MusicFolder = musicDir;
      Scanner.Enabled = false; # would rather manually trigger scans
      EnableInsightsCollector = false;
      ListenBrainz.Enabled = true;
      LastFM.Enabled = true;
      LastFM.ScrobbleFirstArtistOnly = true; # lastfm doesn't support multiple artists very well
      UILoginBackgroundUrl = pkgs.${ns}.wallpapers.bw-mountains.url;

      Backup = {
        Path = "/var/backup/navidrome";
        Schedule = "0 14 * * *";
        Count = 1;
      };
    };
  };

  systemd.services.navidrome.serviceConfig = {
    BindPaths = [ "/var/backup/navidrome" ];
    EnvironmentFile = navidromeVars.path;
  };

  ns.services.caddy.virtualHosts.navidrome.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString config.services.navidrome.settings.Port}
  '';

  systemd.tmpfiles.rules = [
    "d /var/backup/navidrome 0700 navidrome navidrome - -"
  ];

  ns.backups.navidrome = {
    backend = "restic";
    paths = [ "/var/backup/navidrome" ];
    restore.pathOwnership."/var/backup/navidrome" = {
      user = "navidrome";
      group = "navidrome";
    };
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/navidrome";
      user = "navidrome";
      group = "navidrome";
      mode = "0700";
    }
    {
      directory = "/var/backup/navidrome";
      user = "navidrome";
      group = "navidrome";
      mode = "0700";
    }
  ];
}
