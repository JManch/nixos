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

    package =
      (pkgs.navidrome.overrideAttrs (
        final: prev:
        assert lib.assertMsg (prev.version == "0.54.5") "Remove navidrome override";
        {
          version = "0.55.0";
          src = pkgs.fetchFromGitHub {
            owner = "navidrome";
            repo = "navidrome";
            rev = "v${final.version}";
            hash = "sha256-PCy8ZgkCwli1YYmMzoQn0gwjOFTm2TANUa2NZ5kFtbM=";
          };
          vendorHash = "sha256-IF2RaEsuHADnwONrvwbL6KZVrE3bZx1sX03zpmtQZq8=";
          npmDeps = pkgs.fetchNpmDeps {
            inherit (final) src;
            sourceRoot = "${final.src.name}/ui";
            hash = "sha256-lM8637tcKc9iSPjXJPDZXFCGj7pShOXTC6X2iketg90=";
          };
          ldflags = [
            "-X github.com/navidrome/navidrome/consts.gitSha=${final.src.rev}"
            "-X github.com/navidrome/navidrome/consts.gitTag=v${final.version}"
          ];
        }
      )).override
        {
          taglib = pkgs.taglib.overrideAttrs (
            final: prev: {
              version = "2.0.2";
              src = pkgs.fetchFromGitHub {
                owner = "taglib";
                repo = "taglib";
                rev = "v${final.version}";
                hash = "sha256-3cJwCo2nUSRYkk8H8dzyg7UswNPhjfhyQ704Fn9yNV8=";
              };
              buildInputs = prev.buildInputs ++ [ pkgs.utf8cpp ];
              cmakeFlags = [
                (lib.cmakeBool "BUILD_SHARED_LIBS" (!pkgs.stdenv.hostPlatform.isStatic))
              ];
            }
          );
        };

    settings = {
      Address = "127.0.0.1";
      MusicFolder = (optionalString impermanence.enable "/persist") + cfg.musicDir;
      Scanner.Schedule = 0; # would rather manually trigger scans
      EnableInsightsCollector = false;
      ListenBrainz.Enabled = true;
      LastFM.Enabled = true;

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
