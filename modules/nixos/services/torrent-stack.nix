{
  lib,
  pkgs,
  config,
  inputs,
  username,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
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
  inherit (config.${ns}.services) caddy;
  inherit (config.${ns}.system) impermanence;
  inherit (inputs.nix-resources.secrets) qBittorrentPort soulseekPort;
  inherit (config.${ns}.device) vpnNamespace;
  inherit (config.age.secrets) recyclarrSecrets slskdVars;
  cfg = config.${ns}.services.torrent-stack;
  mediaDir = (optionalString impermanence.enable "/persist") + cfg.mediaDir;
  vpnNamespaceAddress = config.vpnNamespaces.${vpnNamespace}.namespaceAddress;

  mkArrBackup = service: {
    paths = [ "/var/lib/${service}/Backups" ];
    restore.pathOwnership."/var/lib/${service}" = {
      user = service;
      group = service;
    };
  };

  # Arr config is very imperative so these have to be hardcoded
  ports = {
    qbittorrent = 8087;
    sonarr = 8989;
    radarr = 7878;
    prowlarr = 9696;
    slskd = 5030;
  };
in
mkMerge [
  (mkIf (cfg.video.enable || cfg.music.enable) {
    assertions = asserts [
      caddy.enable
      "Torrent stack requires Caddy to be enabled"
      (cfg.mediaDir != "" && cfg.mediaDir != "/")
      "Torrent stack media dir must not be empty or root"
      (head (stringToCharacters cfg.mediaDir) == "/")
      "Torrent stack media dir must be an absolute path"
      (!hasPrefix "/persist" cfg.mediaDir)
      "Torrent stack media dir should NOT be prefixed with /persist"
    ];

    systemd.tmpfiles.rules = [
      "d ${mediaDir} 0770 root media - -"
      # Torrents are downloaded and seeded here. They are hardlinked by the
      # relevant arr service to a media dir.
      "d ${mediaDir}/torrents 0775 root media - -"
      "d ${mediaDir}/torrents/movies 0775 qbittorrent-nox qbittorrent-nox - -"
      "d ${mediaDir}/torrents/shows 0775 qbittorrent-nox qbittorrent-nox - -"
      "d ${mediaDir}/torrents/music 0775 qbittorrent-nox qbittorrent-nox - -"
      "d ${mediaDir}/movies 0775 root media - -"
      "d ${mediaDir}/shows 0775 root media - -"
      "d ${mediaDir}/books 0775 root media - -"
      "d ${mediaDir}/music 0775 root media - -"
    ];

    users.groups.media = { };
    users.users.${username}.extraGroups = [ "media" ];

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
        # arr apps can create hard links. File access should still be protected
        # by parent media dir.
        UMask = "0000";
        StateDirectory = "qbittorrent-nox";
        StateDirectoryMode = "750";
        ReadWritePaths = [ "${mediaDir}/torrents" ];
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

    ${ns}.services.caddy.virtualHosts = {
      torrents.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.qbittorrent}";
      prowlarr.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.prowlarr}";
    };

    systemd.services.jellyfin.serviceConfig.SupplementaryGroups = [ "media" ];

    backups = {
      prowlarr = mkArrBackup "prowlarr";
      qbittorrent-nox = {
        paths = [ "/var/lib/qbittorrent-nox/qBittorrent/config" ];
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
    };

    persistence.directories = [
      {
        directory = "/var/lib/qbittorrent-nox";
        user = "qbittorrent-nox";
        group = "qbittorrent-nox";
        mode = "0750";
      }
      {
        directory = "/var/lib/prowlarr";
        user = "prowlarr";
        group = "prowlarr";
        mode = "0750";
      }
    ];
  })

  (mkIf cfg.video.enable {
    # FIX: Remove once https://github.com/NixOS/nixpkgs/issues/360592 is resolved
    nixpkgs.config.permittedInsecurePackages = [
      "aspnetcore-runtime-6.0.36"
      "aspnetcore-runtime-wrapped-6.0.36"
      "dotnet-sdk-6.0.428"
      "dotnet-sdk-wrapped-6.0.428"
    ];

    # Upstream arr modules are very barebones so might as well define our own
    # services

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
        ReadWritePaths = [
          "${mediaDir}/shows"
          "${mediaDir}/torrents/shows"
        ];
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
        ReadWritePaths = [
          "${mediaDir}/movies"
          "${mediaDir}/torrents/movies"
        ];
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
      isSystemUser = true;
    };

    systemd.services.recyclarr =
      let
        dataDir = "/var/lib/recyclarr";

        templates = pkgs.runCommand "recyclarr-merged-templates" { } ''
          mkdir $out
          cp --no-preserve=mode -r "${inputs.recyclarr-templates}"/radarr/includes $out
          cp --no-preserve=mode -r "${inputs.recyclarr-templates}"/sonarr/includes $out
        '';

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
                  install -m644 "${recyclarrConfig}" "${dataDir}"/recyclarr.yaml
                  install -m644 "${recyclarrSecrets.path}" "${dataDir}"/secrets.yaml
                  sed 's/sonarr_api_key/!secret sonarr_api_key/' -i "${dataDir}"/recyclarr.yaml
                  sed 's/radarr_api_key/!secret radarr_api_key/' -i "${dataDir}"/recyclarr.yaml
                  ln -sf "${templates}"/includes -t "${dataDir}"
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

    # WARN: This allows prowlarr to access sonarr and radarr over the VPN bridge
    # interface. Note that the VPN service must be restarted for these firewall
    # rules to take effect.
    networking.firewall.interfaces."${vpnNamespace}-br".allowedTCPPorts = [
      ports.sonarr
      ports.radarr
    ];

    ${ns}.services.caddy.virtualHosts = {
      sonarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.sonarr}";
      radarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.radarr}";
    };

    backups = genAttrs [
      "radarr"
      "sonarr"
    ] mkArrBackup;

    persistence.directories = [
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
        directory = "/var/lib/recyclarr";
        user = "recyclarr";
        group = "recyclarr";
        mode = "0750";
      }
    ];
  })

  (mkIf cfg.music.enable {
    # Import new music with `beet import --timid --from-scratch /path/to/music`

    # WARN: When importing to replace an existing import, the "Remove old"
    # option does not remove the cover file so that has to be done manually
    # first to avoid a duplicate cover being added.

    # When picking a release prefer digital releases as they have the best
    # cover on musicbrainz

    # To change the musicbrainz release of an album first re-import with `beet
    # import --timid --library <query>` (use -s to target a single track) then
    # choose the correct musicbrainz release. For some reason not all metadata
    # gets updated after this so run `beet mbsync <query>`.
    environment.systemPackages = singleton (
      pkgs.symlinkJoin {
        name = "beets-wrapped-config";
        paths = singleton (
          pkgs.beets.override {
            pluginOverrides = {
              replaygain.enable = true;
              autobpm.enable = true;
              fetchart.enable = true;
              embedart.enable = true;
              lyrics.enable = true;
              mbsync.enable = true;
              missing.enable = true;
              permissions.enable = true;
              unimported.enable = true;
            };
          }
        );
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild =
          let
            config = (pkgs.formats.yaml { }).generate "beets-config.yaml" {
              directory = "${mediaDir}/music";
              library = "${mediaDir}/music/library.db";
              plugins = [
                "replaygain"
                "autobpm"
                "fetchart"
                "embedart"
                "lyrics"
                "mbsync" # provides command to fetch latest metadata from musicbrainz
                "missing"
                "permissions"
                "unimported"
              ];

              incremental = false; # creates unwanted state.pickel file
              autobpm.auto = true;
              lyrics.auto = true;
              asciify_paths = true;

              fetchart = {
                auto = true;
                sources = [
                  "filesystem"
                  { coverart = "release"; }
                  { coverart = "releasegroup"; }
                  "itunes"
                  "albumart"
                ];
              };

              match = {
                # Always prefer digital releases
                max_rec.media = "medium";
                preferred.media = [ "Digital Media" ];
                ignored_media = [
                  "12\" Vinyl"
                  "Vinyl"
                ];
              };

              # some release groups have lots of CD/vinyls
              musicbrainz.searchlimit = 20;

              embedart = {
                auto = true;
                maxwidth = 600; # shrink album covers to a sensible size when embedding
                minwidth = 1000;
              };

              # some files may be owned by slskd:slskd
              permissions = {
                file = 666;
                dir = 777;
              };

              import = {
                write = true;
                move = true;
              };

              replaygain = {
                auto = true;
                backend = "ffmpeg";
                overwrite = true;
              };
            };
          in
          ''
            wrapProgram $out/bin/beet --add-flags "--config=${config}"
          '';
      }
    );

    services.slskd = {
      enable = true;
      domain = null;
      environmentFile = slskdVars.path;
      openFirewall = false;
      settings = {
        soulseek.listen_port = soulseekPort;
        directories.downloads = "${mediaDir}/slskd/downloads";
        directories.incomplete = "${mediaDir}/slskd/incomplete";
        flags.no_config_watch = true;
        retention.search = 4320; # retain completed searches for 3 days
        global.upload.speed_limit = 100000;
        global.download.speed_limit = 100000;

        shares = {
          directories = [
            "${mediaDir}/music"
            "!${mediaDir}/music/playlists"
          ];
          filters = [
            "^library\.db$"
            "\.nsp$"
            "\.m3u$"
          ];
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${mediaDir}/slskd 0775 root media - -"
      "d ${mediaDir}/slskd/downloads 0775 root media - -"
      "d ${mediaDir}/slskd/incomplete 0775 root media - -"
    ];

    systemd.services.slskd = {
      serviceConfig = {
        StateDirectoryMode = "750";
        SupplementaryGroups = [ "media" ];
        # Same reason as qbittorrent
        UMask = "0000";
      };
      # slskd creates an inotify watch for every directory in the nix store.
      # This breaks jellyfin and probably a bunch of other stuff
      # https://github.com/slskd/slskd/issues/1050
      environment.DOTNET_USE_POLLING_FILE_WATCHER = "1";
      vpnConfinement = {
        inherit vpnNamespace;
        enable = true;
      };
    };

    vpnNamespaces.${vpnNamespace} = {
      portMappings = singleton {
        from = ports.slskd;
        to = ports.slskd;
      };

      openVPNPorts = singleton {
        port = soulseekPort;
        protocol = "both";
      };
    };

    ${ns}.services.caddy.virtualHosts = {
      slskd.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.slskd}";
    };

    persistence.directories = singleton {
      directory = "/var/lib/slskd";
      user = "slskd";
      group = "slskd";
      mode = "0750";
    };
  })
]
