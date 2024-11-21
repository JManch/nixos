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
    hasPrefix
    genAttrs
    stringToCharacters
    optionalString
    singleton
    ;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (config.${ns}.services) caddy jellyfin;
  inherit (config.${ns}.system) impermanence;
  inherit (inputs.nix-resources.secrets) qBittorrentPort;
  inherit (config.${ns}.device) vpnNamespace;
  inherit (config.age.secrets) recyclarrSecrets;
  cfg = config.${ns}.services.torrent-stack;
  mediaDir = (optionalString impermanence.enable "/persist") + cfg.mediaDir;

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
    (head (stringToCharacters cfg.mediaDir) == "/")
    "Torrent stack media dir must be an absolute path"
    (!hasPrefix "/persist" cfg.mediaDir)
    "Torrent stack media dir should NOT be prefixed with /persist"
  ];

  systemd.tmpfiles.rules = [
    "d ${mediaDir} 0750 root media - -"
    # Torrents are downloaded and seeded here. They are hardlinked by the
    # relevant arr service to a media dir.
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

  users.groups.recyclarr = { };
  users.users.recyclarr = {
    group = "recyclarr";
    home = "/var/lib/recyclarr";
    isSystemUser = true;
  };

  systemd.services.recyclarr =
    let
      inherit (inputs) recyclarr-templates;
      dataDir = "/var/lib/recyclarr";

      recyclarrConfig = (pkgs.formats.yaml { }).generate "recyclarr.yaml" {
        sonarr.shows = {
          delete_old_custom_formats = true;
          replace_existing_custom_formats = true;
          base_url = "http://localhost:${toString ports.sonarr}";
          api_key = "sonarr_api_key";

          include = [
            { template = "sonarr-quality-definition-series"; }
            { template = "sonarr-v4-quality-profile-web-1080p"; }
            { template = "sonarr-v4-custom-formats-web-1080p"; }
            { template = "sonarr-quality-definition-anime"; }
            { template = "sonarr-v4-quality-profile-anime"; }
            { template = "sonarr-v4-custom-formats-anime"; }
          ];
        };

        radarr.movies = {
          delete_old_custom_formats = true;
          replace_existing_custom_formats = true;
          base_url = "http://localhost:${toString ports.radarr}";
          api_key = "radarr_api_key";

          include = [
            { template = "radarr-quality-definition-movie"; }
            { template = "radarr-quality-profile-remux-web-1080p"; }
            { template = "radarr-custom-formats-remux-web-1080p"; }
            { template = "radarr-quality-profile-anime"; }
            { template = "radarr-custom-formats-anime"; }
          ];
        };
      };
    in
    {
      description = "Recyclarr";
      startAt = "Wed *-*-* 12:00:00";

      after = [
        "network.target"
        "radarr.service"
        "sonarr.service"
      ];
      requisite = [
        "radarr.service"
        "sonarr.service"
      ];

      serviceConfig = hardeningBaseline config {
        DynamicUser = false;
        User = "recyclarr";
        Group = "recyclarr";
        ExecStartPre = getExe (
          pkgs.writeShellApplication {
            name = "recyclarr-setup";
            runtimeInputs = with pkgs; [
              gnused
              coreutils
            ];
            text = # bash
              ''
                cat ${recyclarrConfig} > "${dataDir}/recyclarr.yaml"

                cat "${recyclarrSecrets.path}" > "${dataDir}/secrets.yaml"
                sed 's/sonarr_api_key/!secret sonarr_api_key/' -i "${dataDir}/recyclarr.yaml"
                sed 's/radarr_api_key/!secret radarr_api_key/' -i "${dataDir}/recyclarr.yaml"

                rm -rf "${dataDir}/includes"
                cp --no-preserve=mode -r "${recyclarr-templates}/radarr/includes" "${dataDir}"
                cp --no-preserve=mode -r "${recyclarr-templates}/sonarr/includes" "${dataDir}"
              '';
          }
        );
        ExecStart = "${getExe pkgs.recyclarr} sync --app-data ${dataDir}";
        StateDirectory = "recyclarr";
        StateDirectoryMode = "750";
        MemoryDenyWriteExecute = false;
        # sed -i doesn't work with ~@priviledged
        SystemCallFilter = [ "@system-service" ];
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
            pathOwnership."/var/lib/qbittorrent-nox" = {
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
        restore.pathOwnership."/var/lib/${service}" = {
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
    {
      directory = "/var/lib/prowlarr";
      user = "prowlarr";
      group = "prowlarr";
      mode = "0750";
    }
  ];
}
