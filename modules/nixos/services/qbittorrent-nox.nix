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
    mkIf
    utils
    getExe'
    singleton
    ;
  inherit (config.modules.services) wgnord caddy nfs;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (caddy) allowAddresses trustedAddresses;
  cfg = config.modules.services.qbittorrent-nox;
  qbittorrent-nox = pkgs.qbittorrent.override { guiSupport = false; };
in
mkIf cfg.enable {
  assertions = utils.asserts [
    wgnord.enable
    "qBittorrent nox requires wgnord to be enabled"
    caddy.enable
    "qBittorrent nox requires Caddy to be enabled"
  ];

  users.groups.qbittorrent-nox = { };
  users.users.qbittorrent-nox = {
    group = "qbittorrent-nox";
    isSystemUser = true;
  };

  users.users.${username}.extraGroups = [ "qbittorrent-nox" ];

  systemd.services.qbittorrent-nox = {
    description = "qBittorrent-nox";
    after = [
      "network-online.target"
      "wgnord.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "wgnord.service" ];

    environment = {
      QBT_PROFILE = "/var/lib/qbittorrent-nox";
      QBT_WEBUI_PORT = toString cfg.port;
    };

    serviceConfig = utils.hardeningBaseline config {
      DynamicUser = false;
      User = "qbittorrent-nox";
      Group = "qbittorrent-nox";
      StateDirectory = "qbittorrent-nox";
      ExecStart = getExe' qbittorrent-nox "qbittorrent-nox";
      Restart = "always";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      UMask = "0002";
    };

    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin 0775 qbittorrent-nox qbittorrent-nox"
  ];

  fileSystems."/export/jellyfin" = mkIf nfs.server.enable {
    device = "/var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin";
    options = [ "bind" ];
  };

  modules.services.nfs.server.fileSystems =
    let
      inherit (config.modules.system.reservedIDs.jellyfin) uid gid;
    in
    [
      {
        path = "jellyfin";
        clients = {
          # all_squash doesn't change the ownership of existing files
          # It just affects the access priviledges somehow through NFS I think?
          "ncase-m1.lan" = "ro,no_subtree_check,all_squash,anonuid=${toString uid},anongid=${toString gid}";
        };
      }
    ];

  services.caddy.virtualHosts."torrents.${fqDomain}".extraConfig = ''
    ${allowAddresses trustedAddresses}
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  backups.qbittorrent-nox =
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

  persistence.directories = singleton {
    directory = "/var/lib/qbittorrent-nox";
    user = "qbittorrent-nox";
    group = "qbittorrent-nox";
    mode = "750";
  };
}
