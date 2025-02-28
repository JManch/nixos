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

    package = pkgs.navidrome.overrideAttrs (
      final: _:
      assert lib.assertMsg (pkgs.navidrome.version == "0.54.3") "Remove the navidrome override";
      {
        version = "0.54.5";
        src = pkgs.fetchFromGitHub {
          owner = "navidrome";
          repo = "navidrome";
          rev = "v${final.version}";
          hash = "sha256-74sN2qZVjsD5i3BkJKYcpL3vZsVIg0H5RI70oRdZpi0=";
        };
        vendorHash = "sha256-bI0iDhATvNylKnI81eeUpgsm8YqySPyinPgBbcO0y4I=";
      }
    );

    openFirewall = false;
    settings = {
      Address = "127.0.0.1";
      MusicFolder = (optionalString impermanence.enable "/persist") + cfg.musicDir;
      ScanSchedule = 0; # would rather manually trigger scans
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

  nsConfig.services.caddy.virtualHosts.navidrome.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString config.services.navidrome.settings.Port}
  '';

  systemd.tmpfiles.rules = [
    "d /var/backup/navidrome 0700 navidrome navidrome - -"
  ];

  backups.navidrome = {
    paths = [ "/var/backup/navidrome" ];
    restore.pathOwnership."/var/backup/navidrome" = {
      user = "navidrome";
      group = "navidrome";
    };
  };

  persistence.directories = [
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
