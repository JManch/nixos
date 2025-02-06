{ lib, config, ... }:
let
  inherit (lib)
    ns
    mkIf
    optionalString
    hasPrefix
    singleton
    ;
  inherit (config.${ns}.services) caddy;
  inherit (config.${ns}.system) impermanence;
  inherit (config.age.secrets) navidromeSpotifyVars;
  cfg = config.${ns}.services.navidrome;
in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "Navidrome requires Caddy to be enabled"
    (!hasPrefix "/persist" cfg.musicDir)
    "Navidrome music dir should NOT be prefixed with /persist"
  ];

  services.navidrome = {
    enable = true;
    openFirewall = false;
    settings = {
      Address = "127.0.0.1";
      MusicFolder = (optionalString impermanence.enable "/persist") + cfg.musicDir;
      ScanSchedule = 0; # would rather manually trigger scans
      EnableInsightsCollector = false;
      ListenBrainz.Enabled = true;

      Backup = {
        Path = "/var/backup/navidrome";
        Schedule = "0 14 * * *";
        Count = 1;
      };
    };
  };

  systemd.services.navidrome.serviceConfig = {
    BindPaths = [ "/var/backup/navidrome" ];
    EnvironmentFile = navidromeSpotifyVars.path;
  };

  ${ns}.services.caddy.virtualHosts.navidrome.extraConfig = ''
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
