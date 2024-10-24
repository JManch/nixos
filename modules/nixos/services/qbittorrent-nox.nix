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
    getExe'
    singleton
    ;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (config.${ns}.services) caddy nfs;
  inherit (inputs.nix-resources.secrets) qBittorrentPort;
  inherit (config.${ns}.device) vpnNamespace;
  cfg = config.${ns}.services.qbittorrent-nox;
  qbittorrent-nox = pkgs.qbittorrent.override { guiSupport = false; };
in
mkIf cfg.enable {
  assertions = asserts [
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
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      QBT_PROFILE = "/var/lib/qbittorrent-nox";
      QBT_WEBUI_PORT = toString cfg.port;
    };

    vpnConfinement = {
      inherit vpnNamespace;
      enable = true;
    };

    serviceConfig = hardeningBaseline config {
      DynamicUser = false;
      User = "qbittorrent-nox";
      Group = "qbittorrent-nox";
      StateDirectory = "qbittorrent-nox";
      StateDirectoryMode = "750";
      ExecStart = getExe' qbittorrent-nox "qbittorrent-nox";
      Restart = "always";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };

    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent-nox/qBittorrent/downloads 0755 qbittorrent-nox qbittorrent-nox - -"
    "d /var/lib/qbittorrent-nox/qBittorrent/downloads-tmp 0755 qbittorrent-nox qbittorrent-nox - -"
  ];

  fileSystems."/export/jellyfin" = mkIf nfs.server.enable {
    device = "/var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin";
    options = [ "bind" ];
  };

  ${ns}.services = {
    nfs.server.fileSystems =
      let
        inherit (config.${ns}.system.reservedIDs.jellyfin) uid gid;
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

    caddy.virtualHosts.torrents.extraConfig = ''
      reverse_proxy http://${config.vpnNamespaces.${vpnNamespace}.namespaceAddress}:${toString cfg.port}
    '';
  };

  vpnNamespaces.${vpnNamespace} = {
    portMappings = singleton {
      from = cfg.port;
      to = cfg.port;
    };

    openVPNPorts = singleton {
      port = qBittorrentPort;
      protocol = "tcp";
    };
  };

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
    mode = "0750";
  };
}
