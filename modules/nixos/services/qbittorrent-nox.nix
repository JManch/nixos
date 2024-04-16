{ lib
, pkgs
, config
, inputs
, outputs
, username
, ...
}:
let
  inherit (lib) mkIf utils getExe';
  inherit (config.modules.services) wgnord caddy nfs;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.qbittorrent-nox;
  qbittorrent-nox = pkgs.qbittorrent.override {
    guiSupport = false;
  };
in
mkIf cfg.enable
{
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
    after = [ "network-online.target" "wgnord.service" ];
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
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
      UMask = "0002";
    };

    wantedBy = [ "multi-user.target" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin 775 qbittorrent-nox qbittorrent-nox"
  ];

  fileSystems."/export/jellyfin" = mkIf nfs.server.enable {
    device = "/var/lib/qbittorrent-nox/qBittorrent/downloads/jellyfin";
    options = [ "bind" ];
  };

  modules.services.nfs.server.fileSystems =
    let
      inherit (outputs.nixosConfigurations.ncase-m1.config) users;
      jellyfinUid = toString users.users.jellyfin.uid;
      jellyfinGid = toString users.groups.jellyfin.gid;
    in
    [{
      path = "jellyfin";
      clients = {
        # all_squash doesn't change the ownership of existing files
        # It just affects the access priviledges somehow through NFS I think?
        "ncase-m1.lan" = "ro,no_subtree_check,all_squash,anonuid=${jellyfinUid},anongid=${jellyfinGid}";
      };
    }];

  services.caddy.virtualHosts."torrents.${fqDomain}".extraConfig = ''
    import lan_only
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  persistence.directories = [{
    directory = "/var/lib/qbittorrent-nox";
    user = "qbittorrent-nox";
    group = "qbittorrent-nox";
    mode = "750";
  }];
}
