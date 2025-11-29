{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  sources,
  username,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    head
    mkForce
    hasPrefix
    genAttrs
    stringToCharacters
    optionalString
    singleton
    ;
  inherit (lib.${ns}) hardeningBaseline;
  inherit (config.${ns}.system) impermanence;
  inherit (config.${ns}.services) jellyfin;
  inherit (config.${ns}.core) device;
  inherit (inputs.nix-resources.secrets) qBittorrentPort soulseekPort slskdExcludePaths;
  inherit (config.age.secrets) recyclarrSecrets slskdVars;
  mediaDir = (optionalString impermanence.enable "/persist") + cfg.mediaDir;
  vpnNamespaceAddress = config.vpnNamespaces.${device.vpnNamespace}.namespaceAddress;

  mkArrBackup = service: {
    backend = "restic";
    paths = [ "/var/lib/${service}/Backups" ];
    restore = {
      preRestoreScript = "sudo systemctl stop ${service}";
      pathOwnership."/var/lib/${service}" = {
        user = service;
        group = service;
      };
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
[
  {
    enableOpt = false;
    guardType = "custom";

    opts = with lib; {
      video.enable = mkEnableOption "Video torrent stack";
      music.enable = mkEnableOption "Music torrent stack";

      mediaDir = mkOption {
        type = types.str;
        default = "/data/media";
        description = ''
          Absolute path to directory where torrent downloads and media library
          will be stored.
        '';
      };
    };
  }

  (mkIf (cfg.video.enable || cfg.music.enable) {
    requirements = [ "services.caddy" ];

    asserts = [
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

    # WARN: It's important I do not use DynamicUser for qbittorrent, sonnar or
    # radarr as these services need to be able to create files/directories
    # under /media and the ownership would be vulnerable to GID/UID recycling.
    systemd.services.qbittorrent-nox = {
      description = "qBittorrent-nox";
      after = [ "network.target" ];

      environment = {
        QBT_PROFILE = "/var/lib/qbittorrent-nox";
        QBT_WEBUI_PORT = toString ports.qbittorrent;
        QBT_TORRENTING_PORT = toString qBittorrentPort;
        QBT_CONFIRM_LEGAL_NOTICE = "1";
      };

      vpnConfinement = {
        enable = true;
        inherit (device) vpnNamespace;
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

        # Make file system inaccessible
        TemporaryFileSystem = "/";
        BindReadOnlyPaths = [
          builtins.storeDir
          "/etc/ssl/certs"
        ];
        BindPaths = [
          "/var/lib/qbittorrent-nox"
          "${mediaDir}/torrents"
        ];
      };

      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.prowlarr = {
      description = "Prowlarr";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment.HOME = "/var/empty";

      vpnConfinement = {
        enable = true;
        inherit (device) vpnNamespace;
      };

      serviceConfig = hardeningBaseline config {
        DynamicUser = true;
        ExecStart = "${getExe pkgs.prowlarr} -nobrowser -data=/var/lib/private/prowlarr";
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

    vpnNamespaces.${device.vpnNamespace} = {
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

    ns.services.caddy.virtualHosts = {
      torrents.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.qbittorrent}";
      prowlarr.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.prowlarr}";
    };

    systemd.services.jellyfin = mkIf jellyfin.enable {
      serviceConfig.SupplementaryGroups = [ "media" ];
    };

    ns.backups = {
      prowlarr = {
        backend = "restic";
        paths = [ "/var/lib/private/prowlarr/Backups" ];
        restore = {
          preRestoreScript = "sudo systemctl stop prowlarr";
          pathOwnership."/var/lib/private/prowlarr" = {
            user = "nobody";
            group = "nogroup";
          };
        };
      };
      qbittorrent-nox = {
        backend = "restic";
        paths = [ "/var/lib/qbittorrent-nox/qBittorrent/config" ];
        backendOptions.exclude = [
          "ipc-socket"
          "lockfile"
          "*.lock"
        ];

        restore = {
          removeExisting = false;
          preRestoreScript = "sudo systemctl stop qbittorrent-nox";
          pathOwnership."/var/lib/qbittorrent-nox" = {
            user = "qbittorrent-nox";
            group = "qbittorrent-nox";
          };
        };
      };
    };

    ns.persistence.directories = [
      {
        directory = "/var/lib/qbittorrent-nox";
        user = "qbittorrent-nox";
        group = "qbittorrent-nox";
        mode = "0750";
      }
      {
        directory = "/var/lib/private/prowlarr";
        user = "nobody";
        group = "nogroup";
        mode = "0750";
      }
    ];
  })

  (mkIf cfg.video.enable {
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

    systemd.services.recyclarr =
      let
        dataDir = "/var/lib/private/recyclarr";

        templates = pkgs.runCommand "recyclarr-merged-templates" { } ''
          mkdir $out
          cp --no-preserve=mode -r "${sources.recyclarr-templates}"/radarr/includes $out
          cp --no-preserve=mode -r "${sources.recyclarr-templates}"/sonarr/includes $out
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
          DynamicUser = true;
          ExecStartPre = getExe (
            pkgs.writeShellApplication {
              name = "recyclarr-setup";
              runtimeInputs = with pkgs; [
                gnused
                coreutils
              ];
              text = ''
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
    networking.firewall.interfaces."${device.vpnNamespace}-br".allowedTCPPorts = [
      ports.sonarr
      ports.radarr
    ];

    ns.services.caddy.virtualHosts = {
      sonarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.sonarr}";
      radarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.radarr}";
    };

    ns.backups = genAttrs [
      "radarr"
      "sonarr"
    ] mkArrBackup;

    ns.persistence.directories = [
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
        directory = "/var/lib/private/recyclarr";
        user = "nobody";
        group = "nogroup";
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
    ns.userPackages = [
      pkgs.${ns}.resample-flacs
      (pkgs.symlinkJoin {
        name = "beets-wrapped-config";
        paths = singleton (
          pkgs.python3Packages.beets.override {
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
              hook.enable = true;
            };
          }
        );
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild =
          let
            config = (pkgs.formats.yaml { }).generate "beets-config.yaml" {
              directory = "${mediaDir}/music";
              library = "${mediaDir}/music/library.db";
              paths.singleton = "$albumartist/Non-Album/$title";

              plugins = [
                "musicbrainz"
                "replaygain"
                "autobpm"
                "fetchart"
                "embedart"
                "lyrics"
                "mbsync" # provides command to fetch latest metadata from musicbrainz
                "missing"
                "permissions"
                "unimported"
                "hook"
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

              hook.hooks = singleton {
                event = "before_item_imported";
                command = "${
                  getExe (
                    pkgs.writeShellApplication {
                      name = "beets-resample-flac";
                      runtimeInputs = [ pkgs.sox ];
                      text = ''
                        input_file="$1"
                        filename=$(basename "$input_file")

                        if [[ $filename != *.flac ]]; then
                          exit 0
                        fi

                        if [[ -f /tmp/beets-disable-resample ]]; then
                          echo "Beets resampling is disabled so skipping"
                          exit 0
                        fi

                        sample_rate=$(soxi -r "$input_file")
                        bitrate=$(soxi -b "$input_file")
                        tmp_file=$(mktemp -p /tmp "resample-flac-tmp.XXXXXX.flac")
                        trap 'rm -f "$tmp_file"' EXIT

                        if [[ $sample_rate -gt 44100 || $bitrate -gt 16 ]]; then
                          sox -G "$input_file" -b 16 --comment "" "$tmp_file" rate -v 44100
                          echo "Resampled $filename: $bitrate/''${sample_rate}Hz -> 16/44100Hz"
                        else
                          echo "Skipping $filename: $bitrate/''${sample_rate}Hz"
                          exit 0
                        fi

                        mv "$tmp_file" "$input_file"
                      '';
                    }
                  )
                } \"{source}\"";
              };

              match = {
                # Always prefer digital releases
                max_rec.media = "medium";
                preferred.media = [ "Digital Media" ];
                ignored_media = [
                  # Vinyl usually has bad cover art on musicbrainz
                  "12\" Vinyl"
                  "Vinyl"
                ];
              };

              # some release groups have lots of CD/vinyls
              musicbrainz.search_limit = 20;

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
      })
    ];

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
          ]
          ++ map (p: "!${mediaDir}/${p}") slskdExcludePaths;

          filters = [
            "library\\.db$"
            "\\.nsp$"
            "\\.m3u$"
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

        # Upstream implementation makes no sense as shares.directories may
        # contain exclusion rules. Also doesn't handle paths with spaces
        # correctly.
        ReadOnlyPaths = mkForce [ ];

        # Make file system inaccessible
        TemporaryFileSystem = "/";
        BindReadOnlyPaths = [
          builtins.storeDir
          "${mediaDir}/music"
          "/run/agenix/slskdVars"
        ];
        BindPaths = [
          "/var/lib/slskd"
          "${mediaDir}/slskd"
        ];
      };
      # slskd creates an inotify watch for every directory in the nix store.
      # This breaks jellyfin and probably a bunch of other stuff
      # https://github.com/slskd/slskd/issues/1050
      environment.DOTNET_USE_POLLING_FILE_WATCHER = "1";
      vpnConfinement = {
        inherit (device) vpnNamespace;
        enable = true;
      };
    };

    vpnNamespaces.${device.vpnNamespace} = {
      portMappings = singleton {
        from = ports.slskd;
        to = ports.slskd;
      };

      openVPNPorts = singleton {
        port = soulseekPort;
        protocol = "both";
      };
    };

    ns.services.caddy.virtualHosts.slskd.extraConfig =
      "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.slskd}";

    ns.backups = {
      music = {
        backend = "rclone";
        paths = [ "${cfg.mediaDir}/music" ];

        notifications = {
          failure.config = {
            discord.enable = true;
            discord.var = "MUSIC";
          };

          success = {
            enable = true;
            config = {
              discord.enable = true;
              discord.var = "MUSIC";
            };
          };
        };

        timerConfig = {
          OnCalendar = "Sun *-*-* 8:00:00";
          Persistent = false;
        };

        backendOptions = {
          remote = "filen";
          mode = "sync";
          remotePaths."${cfg.mediaDir}/music" = "music";
          flags = [ "--bwlimit 5M" ];
          check = {
            # Filen uses a case-insensitive file system so syncs can break if we change the
            # case of local directory names. Basically results in every backup run
            # attempting to re-upload the "renamed" directory with the remote directory
            # never changing.

            # Enabling checks allows us to detect when this happens so we can manually
            # intervene and fix it. A proper solution would be to use --track-renames but
            # it seems like the filen rclone implementation does not support move
            # operations: `PostV3FileMove: response error: Cannot move this file.
            # cannot_move_this_file : can't move object - incompatible remotes`
            enable = true;
            flags = [ "--size-only" ];
          };
        };
      };

      slskd = {
        backend = "restic";
        paths = [ "/var/lib/slskd/data" ];

        backendOptions.exclude = [
          "search*"
          "shares*"
          "*.cache"
          "events.db"
        ];

        restore = {
          removeExisting = false;
          preRestoreScript = "sudo systemctl stop slskd";
          pathOwnership."/var/lib/slskd" = {
            user = "slskd";
            group = "slskd";
          };
        };
      };
    };

    ns.persistence.directories = singleton {
      directory = "/var/lib/slskd";
      user = "slskd";
      group = "slskd";
      mode = "0750";
    };
  })
]
