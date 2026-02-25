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

# SQL for copying annotation table data from old item_ids to new. All
# annotation columns for record with the left item_id will be copied to a new
# record (or update the existing record) for record with the right item_id.

# WARN: Remember to also copy the item_id for the album itself

# CREATE TEMP TABLE pair_map (source_id TEXT, target_id TEXT);
#
# INSERT INTO pair_map VALUES
#   ('1ac504f64791bcc97f70c0c84ceae1cc', 'VhnGUWj9DEYNUcBpEUndnd'),
#   ('ce72aad6c70a55462da61ced7686cebe', 'jT1vuPB4egCCOf6PPujERn'),
#   ('397f5eb79ee115699f2495ddddace20b', 'vDzBSUe1bzlUkNwqsTsua8');
#
# INSERT INTO annotation (user_id, item_id, item_type, play_count, play_date, rating, starred, starred_at, rated_at)
# SELECT a.user_id, p.target_id, a.item_type, a.play_count, a.play_date, a.rating, a.starred, a.starred_at, a.rated_at
# FROM annotation a
# JOIN pair_map p ON a.item_id = p.source_id
# ON CONFLICT (user_id, item_id, item_type) DO UPDATE SET
#   play_count = excluded.play_count,
#   play_date  = excluded.play_date,
#   rating     = excluded.rating,
#   starred    = excluded.starred,
#   starred_at = excluded.starred_at,
#   rated_at   = excluded.rated_at;
#
# DROP TABLE pair_map;
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
