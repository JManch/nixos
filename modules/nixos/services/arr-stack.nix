{
  lib,
  pkgs,
  config,
  sources,
}:
let
  inherit (lib) ns getExe singleton;
  inherit (lib.${ns}) hardeningBaseline;
  inherit (config.${ns}.core) device;
  inherit (config.${ns}.hardware.file-system) mediaDir;
  inherit (config.age.secrets) recyclarrSecrets;
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
    {
      directory = "/var/lib/private/recyclarr";
      user = "nobody";
      group = "nogroup";
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
        LoadCredential = "recyclarr-secrets:${recyclarrSecrets.path}";
        ExecStartPre = getExe (
          pkgs.writeShellApplication {
            name = "recyclarr-setup";
            runtimeInputs = with pkgs; [
              gnused
              coreutils
            ];
            text = ''
              install -m644 "${recyclarrConfig}" "${dataDir}"/recyclarr.yaml
              install -m644 "$CREDENTIALS_DIRECTORY/recyclarr-secrets" "${dataDir}"/secrets.yaml
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
    prowlarr.extraConfig = "reverse_proxy http://${vpnNamespaceAddress}:${toString ports.prowlarr}";
    sonarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.sonarr}";
    radarr.extraConfig = "reverse_proxy http://127.0.0.1:${toString ports.radarr}";
  };
}
