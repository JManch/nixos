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
  args,
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
    # package = lib.${ns}.addPatches pkgs.navidrome [ "navidrome-lastfm-apostrophe.patch" ];

    package = pkgs.navidrome.overrideAttrs (
      final: prev:
      assert lib.assertMsg (prev.version == "0.58.5") "Remove navidrome override";
      {
        version = "0.59.0";
        src = pkgs.fetchFromGitHub {
          owner = "navidrome";
          repo = "navidrome";
          tag = "v${final.version}";
          hash = "sha256-YXyNnjaLgu4FXvgsbbzCOZRIuN96h+KDrXmJe1607JI=";
        };

        patches = prev.patches or [ ] ++ [ ../../../patches/navidrome-lastfm-apostrophe.patch ];

        vendorHash = "sha256-FFtTQuXb5GYxZmUiNjZNO6K8QYF0TLH4JU2JmAzZhqQ=";

        npmDeps = pkgs.fetchNpmDeps {
          inherit (final) src;
          sourceRoot = "${final.src.name}/ui";
          hash = "sha256-RTye1ZbxLqfkZUvV0NLN7wcRnri3sC5Lfi8RXVG1bLM=";

        };

        ldflags = [
          "-X github.com/navidrome/navidrome/consts.gitSha=${final.src.rev}"
          "-X github.com/navidrome/navidrome/consts.gitTag=v${final.version}"
        ];
      }
    );

    settings = {
      Address = "127.0.0.1";
      MusicFolder = musicDir;
      Scanner.Enabled = false; # would rather manually trigger scans
      EnableInsightsCollector = false;
      ListenBrainz.Enabled = true;
      LastFM.Enabled = true;
      LastFM.ScrobbleFirstArtistOnly = true; # lastfm doesn't support multiple artists very well
      UILoginBackgroundUrl = (lib.${ns}.flakePkgs args "nix-resources").wallpapers.bw-mountains.url;

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
