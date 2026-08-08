{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns getExe singleton;
  inherit (lib.${ns}) hardeningBaseline;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.hardware.file-system) mediaDir;
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
    sonarr = 8989;
    radarr = 7878;
    prowlarr = 9696;
    slskd = 5030;
  };
in
{
  requirements = [
    "services.caddy"
    "services.qbittorrent-nox"
  ];

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
    portMappings = singleton {
      from = ports.prowlarr;
      to = ports.prowlarr;
    };
  };

  ns.backups = {
    radarr = mkArrBackup "radarr";
    sonarr = mkArrBackup "sonarr";
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
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/private/prowlarr";
      user = "nobody";
      group = "nogroup";
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

  # WARN: This allows prowlarr to access sonarr and radarr over the VPN bridge
  # interface. Note that the VPN service must be restarted for these firewall
  # rules to take effect.
  networking.firewall.interfaces."${device.vpnNamespace}-br".allowedTCPPorts = [
    ports.sonarr
    ports.radarr
  ];

  ns.services.caddy.virtualHosts = {
    prowlarr.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.prowlarr}";
    sonarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.sonarr}";
    radarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.radarr}";
  };
}
