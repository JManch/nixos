{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    singleton
    ns
    mkForce
    ;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.hardware.file-system) mediaDir;
  inherit (inputs.nix-resources.secrets) soulseekPort slskdExcludePaths;
  inherit (config.age.secrets) slskdVars;
  vpnNamespaceAddress = config.vpnNamespaces.${device.vpnNamespace}.namespaceAddress;
  port = 5030;
in
{
  requirements = [ "services.caddy" ];

  systemd.tmpfiles.rules = [
    "d ${mediaDir}/slskd 0775 root media - -"
    "d ${mediaDir}/slskd/downloads 0775 root media - -"
    "d ${mediaDir}/slskd/incomplete 0775 root media - -"
  ];

  services.slskd = {
    enable = true;
    package =
      assert lib.assertMsg (pkgs.slskd.version == "0.24.0") "remove slskd override";
      (import (fetchTree "github:JManch/nixpkgs/74104e0544c39a59ca12a4a1a41597e7a64bc969") {
        inherit (pkgs.stdenv.hostPlatform) system;
      }).slskd;
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
      from = port;
      to = port;
    };

    openVPNPorts = singleton {
      port = soulseekPort;
      protocol = "both";
    };
  };

  ns.services.caddy.virtualHosts.slskd.extraConfig =
    "reverse_proxy http://${vpnNamespaceAddress}:${toString port}";

  ns.backups."slskd" = {
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

  ns.persistence.directories = singleton {
    directory = "/var/lib/slskd";
    user = "slskd";
    group = "slskd";
    mode = "0750";
  };
}
