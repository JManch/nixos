{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  username,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    getExe'
    head
    genAttrs
    stringToCharacters
    singleton
    ;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (config.${ns}.services) caddy jellyfin;
  inherit (inputs.nix-resources.secrets) qBittorrentPort;
  inherit (config.${ns}.device) vpnNamespace;
  inherit (cfg) mediaDir;
  cfg = config.${ns}.services.torrent-stack;

  # Arr config is very imperative so these have to be hardcoded
  ports = {
    qbittorrent = 8087;
    sonarr = 8989;
    radarr = 7878;
    prowlarr = 9696;
  };
in
mkIf cfg.enable {
  assertions = asserts [
    caddy.enable
    "Torrent stack requires Caddy to be enabled"
    (head (stringToCharacters mediaDir) == "/")
    "Media dir must be an absolute path to persistent storage"
  ];

  systemd.tmpfiles.rules = [
    "d ${mediaDir} 0750 root media - -"
    "d ${mediaDir}/torrents 0775 root media - -"
    "d ${mediaDir}/movies 0775 root media - -"
    "d ${mediaDir}/shows 0775 root media - -"
    "d ${mediaDir}/books 0775 root media - -"
  ];

  users.groups.qbittorrent-nox = { };
  users.users.qbittorrent-nox = {
    group = "qbittorrent-nox";
    isSystemUser = true;
  };

  systemd.services.qbittorrent-nox = {
    description = "qBittorrent-nox";
    after = [ "network.target" ];

    environment = {
      QBT_PROFILE = "/var/lib/qbittorrent-nox";
      QBT_WEBUI_PORT = toString ports.qbittorrent;
    };

    vpnConfinement = {
      enable = true;
      inherit vpnNamespace;
    };

    serviceConfig = hardeningBaseline config {
      DynamicUser = false;
      User = "qbittorrent-nox";
      Group = "qbittorrent-nox";
      SupplementaryGroups = [ "media" ];
      # Downloaded files need read+write permissions for all users so that
      # sonarr and radarr can create hard links. File access should still be
      # protected by parent media dir.
      UMask = "0000";
      StateDirectory = "qbittorrent-nox";
      StateDirectoryMode = "750";
      ReadWritePaths = mediaDir;
      ExecStart = getExe' pkgs.qbittorrent-nox "qbittorrent-nox";
      Restart = "on-failure";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };

    wantedBy = [ "multi-user.target" ];
  };

  # Upstream sonarr, radarr, and prowlarr modules are very barebones so might
  # as well define our own services

  users.groups.sonarr = { };
  users.users.sonarr = {
    group = "sonarr";
    isSystemUser = true;
  };

  systemd.services.sonarr = {
    description = "Sonarr";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = hardeningBaseline config {
      DynamicUser = false;
      User = "sonarr";
      Group = "sonarr";
      SupplementaryGroups = [ "media" ];
      ExecStart = "${getExe pkgs.sonarr} -nobrowser -data=/var/lib/sonarr";
      Restart = "on-failure";
      StateDirectory = "sonarr";
      StateDirectoryMode = "750";
      UMask = "0022";
      ReadWritePaths = mediaDir;
      MemoryDenyWriteExecute = false;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };
  };

  users.groups.radarr = { };
  users.users.radarr = {
    group = "radarr";
    isSystemUser = true;
  };

  systemd.services.radarr = {
    description = "Radarr";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = hardeningBaseline config {
      DynamicUser = false;
      User = "radarr";
      Group = "radarr";
      SupplementaryGroups = [ "media" ];
      ExecStart = "${getExe pkgs.radarr} -nobrowser -data=/var/lib/radarr";
      Restart = "on-failure";
      StateDirectory = "radarr";
      StateDirectoryMode = "750";
      UMask = "0022";
      ReadWritePaths = mediaDir;
      MemoryDenyWriteExecute = false;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };
  };

  users.groups.prowlarr = { };
  users.users.prowlarr = {
    group = "prowlarr";
    isSystemUser = true;
  };

  systemd.services.prowlarr = {
    description = "Prowlarr";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/var/empty";

    vpnConfinement = {
      enable = true;
      inherit vpnNamespace;
    };

    serviceConfig = hardeningBaseline config {
      DynamicUser = false;
      User = "prowlarr";
      Group = "prowlarr";
      ExecStart = "${getExe pkgs.prowlarr} -nobrowser -data=/var/lib/prowlarr";
      Restart = "on-failure";
      StateDirectory = "prowlarr";
      StateDirectoryMode = "750";
      MemoryDenyWriteExecute = false;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };
  };

  users.groups.media = { };
  users.users.${username}.extraGroups = [ "media" ];
  systemd.services.jellyfin.serviceConfig.SupplementaryGroups = mkIf jellyfin.enable [ "media" ];

  vpnNamespaces.${vpnNamespace} = {
    portMappings =
      map
        (port: {
          from = port;
          to = port;
        })
        [
          ports.qbittorrent
          ports.prowlarr
        ];

    openVPNPorts = singleton {
      port = qBittorrentPort;
      protocol = "tcp";
    };
  };

  # WARN: This allows prowlarr to access sonarr and radarr over the VPN bridge
  # interface. Note that the VPN service must be restarted for these firewall
  # rules to take effect.
  networking.firewall.interfaces."${vpnNamespace}-br".allowedTCPPorts = [
    8989
    7878
  ];

  ${ns}.services.caddy.virtualHosts =
    let
      vpnAddress = config.vpnNamespaces.${vpnNamespace}.namespaceAddress;
      port = service: toString ports.${service};
    in
    {
      torrents.extraConfig = "reverse_proxy http://${vpnAddress}:${port "qbittorrent"}";
      prowlarr.extraConfig = "reverse_proxy http://${vpnAddress}:${port "prowlarr"}";
      sonarr.extraConfig = "reverse_proxy http://127.0.0.1:${port "sonarr"}";
      radarr.extraConfig = "reverse_proxy http://127.0.0.1:${port "radarr"}";
    };

  backups =
    {
      qbittorrent-nox =
        let
          configPath = "/var/lib/qbittorrent-nox/qBittorrent/config";
        in
        {
          paths = [ configPath ];
          exclude = [
            "ipc-socket"
            "lockfile"
            "*.lock"
          ];

          restore = {
            removeExisting = false;
            pathOwnership.${configPath} = {
              user = "qbittorrent-nox";
              group = "qbittorrent-nox";
            };
          };
        };
    }
    // (genAttrs
      [
        "radarr"
        "sonarr"
        "prowlarr"
      ]
      (service: {
        paths = [ "/var/lib/${service}/Backups" ];
        restore.pathOwnership."/var/lib/${service}/Backups" = {
          user = service;
          group = service;
        };
      })
    );

  persistence.directories = [
    {
      directory = "/var/lib/qbittorrent-nox";
      user = "qbittorrent-nox";
      group = "qbittorrent-nox";
      mode = "0750";
    }
    {
      directory = "/var/lib/sonarr";
      user = "sonarr";
      group = "sonarr";
      mode = "0750";
    }
    {
      directory = "/var/lib/radarr";
      user = "radarr";
      group = "radarr";
      mode = "0750";
    }
  ];
}
