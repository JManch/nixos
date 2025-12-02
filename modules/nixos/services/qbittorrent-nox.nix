{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib) ns singleton getExe';
  inherit (lib.${ns}) hardeningBaseline;
  inherit (config.${ns}.hardware.file-system) mediaDir;
  inherit (config.${ns}.core) device;
  inherit (inputs.nix-resources.secrets) qBittorrentPort;
  vpnNamespaceAddress = config.vpnNamespaces.${device.vpnNamespace}.namespaceAddress;
  port = 8087;
in
{
  systemd.tmpfiles.rules = [
    # Torrents are downloaded and seeded here. They are hardlinked by the
    # relevant arr service to a media dir.
    "d ${mediaDir}/torrents 0775 root media - -"
    "d ${mediaDir}/torrents/movies 0775 qbittorrent-nox qbittorrent-nox - -"
    "d ${mediaDir}/torrents/shows 0775 qbittorrent-nox qbittorrent-nox - -"
    "d ${mediaDir}/torrents/music 0775 qbittorrent-nox qbittorrent-nox - -"
  ];

  users.groups.qbittorrent-nox = { };
  users.users.qbittorrent-nox = {
    group = "qbittorrent-nox";
    isSystemUser = true;
  };

  # WARN: It's important I do not use DynamicUser for qbittorrent, or any of
  # arr apps as these services need to be able to create files/directories
  # under /media and the ownership would be vulnerable to GID/UID recycling.
  systemd.services.qbittorrent-nox = {
    description = "qBittorrent-nox";
    after = [ "network.target" ];

    environment = {
      QBT_PROFILE = "/var/lib/qbittorrent-nox";
      QBT_WEBUI_PORT = toString port;
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

  vpnNamespaces.${device.vpnNamespace} = {
    portMappings = singleton {
      from = port;
      to = port;
    };

    openVPNPorts = singleton {
      port = qBittorrentPort;
      protocol = "tcp";
    };
  };

  ns.backups."qbittorrent-nox" = {
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

  ns.services.caddy.virtualHosts.torrents.extraConfig =
    "reverse_proxy http://${vpnNamespaceAddress}:${toString port}";

  ns.persistence.directories = singleton {
    directory = "/var/lib/qbittorrent-nox";
    user = "qbittorrent-nox";
    group = "qbittorrent-nox";
    mode = "0750";
  };
}
