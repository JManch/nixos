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
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib) ns optionalString hasPrefix;
  inherit (config.${ns}.system) impermanence;
  inherit (config.age.secrets) navidromeVars;
in
{
  opts.musicDir =
    with lib;
    mkOption {
      type = types.str;
      description = "Absolute path to music library";
    };

  requirements = [ "services.caddy" ];
  asserts = [
    (!hasPrefix "/persist" cfg.musicDir)
    "Navidrome music dir should NOT be prefixed with /persist"
  ];

  services.navidrome = {
    enable = true;
    openFirewall = false;
    # package = lib.${ns}.addPatches pkgs.navidrome [ "navidrome-lastfm-apostrophe.patch" ];
    package = pkgs.navidrome.overrideAttrs (
      final: prev:
      assert lib.assertMsg (prev.version == "0.56.1") "Remove navidrome override";
      {
        version = "0.57.0";
        src = pkgs.fetchFromGitHub {
          owner = "navidrome";
          repo = "navidrome";
          tag = "v${final.version}";
          hash = "sha256-KTgh+dA2YYPyNdGr2kYEUlYeRwNnEcSQlpQ7ZTbAjP0=";
        };

        patches = prev.patches or [ ] ++ [ ../../../patches/navidrome-lastfm-apostrophe.patch ];

        postPatch = ''
          ${prev.postPatch}
          substituteInPlace core/playback/mpv/mpv_test.go --replace-fail "/bin/bash" "${pkgs.runtimeShell}"
        '';

        vendorHash = "sha256-/WeEimHCEQbTbCZ+4kXVJdHAa9PJEk1bG1d2j3V9JKM=";

        postBuild = ''
          ls -la /build
        '';

        npmDeps = pkgs.fetchNpmDeps {
          inherit (final) src;
          sourceRoot = "${final.src.name}/ui";
          hash = "sha256-tl6unHz0E0v0ObrfTiE0vZwVSyVFmrLggNM5QsUGsvI=";
        };

        ldflags = [
          "-X github.com/navidrome/navidrome/consts.gitSha=${final.src.rev}"
          "-X github.com/navidrome/navidrome/consts.gitTag=v${final.version}"
        ];
      }
    );

    settings = {
      Address = "127.0.0.1";
      MusicFolder = (optionalString impermanence.enable "/persist") + cfg.musicDir;
      Scanner.Enabled = false; # would rather manually trigger scans
      EnableInsightsCollector = false;
      ListenBrainz.Enabled = true;
      LastFM.Enabled = true;
      LastFM.ScrobbleFirstArtistOnly = true; # lastfm doesn't support multiple artists very well

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
