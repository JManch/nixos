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

    package = pkgs.navidrome.overrideAttrs (
      final: prev:
      assert lib.assertMsg (prev.version == "0.55.2") "Remove navidrome override";
      {
        version = "0.56.0";
        src = pkgs.fetchFromGitHub {
          owner = "navidrome";
          repo = "navidrome";
          tag = "v${final.version}";
          hash = "sha256-/X/2Xb5YOWeuXWZJakVRlkBaBjs/Kqq0W4vQd8NbwFU=";
        };

        vendorHash = "sha256-E7Q3wxUd5JAwERBKD2NZaVyj1kszOxvxeDY0s/fEDfY=";

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
