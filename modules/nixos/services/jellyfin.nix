# WARN: It's important to close the webpage when casting from Jellyfin to
# external clients such as jellyfin-mpv-shim or a TV. This is because the
# Jellyfin client that started the cast will request a large chunk of metadata
# every couple of seconds (presumably to update the cast progress bar?). With
# multiple clients watching this can easily throttle the web server and make
# Jellyfin unusable.
{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    optional
    mkForce
    genAttrs
    singleton
    concatLines
    mkEnableOption
    types
    mkOption
    ;
  inherit (config.${ns}.services) arr-stack;
  inherit (config.${ns}.hardware.file-system) mediaDir;
  inherit (config.services) jellyfin;
in
[
  {
    opts = {
      openFirewall = mkEnableOption "opening the firewall";

      backup = mkEnableOption "Jellyfin backups" // {
        default = true;
      };

      autoStart = mkEnableOption "Jellyfin auto start" // {
        default = true;
      };

      plugins = mkOption {
        type = with types; listOf package;
        default = [ ];
        description = ''
          List of plugin packages to install. All directories in the package
          outpath will be symlinked to the Jellyfin plugin folder.
        '';
      };

      reverseProxy = {
        enable = mkEnableOption "Jellyfin Caddy virtual host";

        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "IP address that reverse proxy should point to";
        };

        extraAllowedAddresses = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of address to give access to Jellyfin in addition to the trusted
            list.
          '';
        };
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for Jellyfin to be exposed on.
        '';
      };

      seerr = {
        enable = mkEnableOption "Seerr behind a reverse proxy";

        port = mkOption {
          type = types.port;
          default = 5055;
          description = "Seerr listening port";
        };

        extraAllowedAddresses = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of address to give access to Seerr in addition to the trusted
            list.
          '';
        };
      };
    };

    asserts = [
      (mediaDir != null)
      "Jellyfin requires 'mediaDir' to be set"
    ];

    services.jellyfin = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    systemd.services.jellyfin = {
      preStart =
        mkIf (cfg.plugins != [ ]) # bash
          ''
            mkdir -p /var/lib/jellyfin/plugins
            ${getExe pkgs.fd} --base-directory /var/lib/jellyfin/plugins --exclude configurations --max-depth 1 --type dir --exec rm -r
            ${concatLines (
              # Jellyfin needs write access to create meta.json
              map (plugin: "cp --no-preserve=mode -r ${plugin}/* /var/lib/jellyfin/plugins ") cfg.plugins
            )}
          '';

      serviceConfig = {
        SupplementaryGroups = [ "media" ];
        StateDirectory = "jellyfin";
        CacheDirectory = "jellyfin";
        StateDirectoryMode = "0700";
        ProtectSystem = mkForce "strict";
      };
      wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
    };

    networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
      allowedTCPPorts = [
        8096
        8920
      ];
      allowedUDPPorts = [
        1900
        7359
      ];
    });

    # Jellyfin module has good default hardening

    ns.backups.jellyfin = mkIf cfg.backup {
      backend = "restic";
      paths = [ "/var/lib/jellyfin" ];
      backendOptions.exclude = [
        "transcodes"
        "media"
        "log"
        "metadata"
      ];
      restore = {
        preRestoreScript = "sudo systemctl stop jellyfin";
        pathOwnership = {
          "/var/lib/jellyfin" = {
            user = "jellyfin";
            group = "jellyfin";
          };
        };
      };
    };

    ns.persistence.directories = [
      {
        directory = "/var/lib/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "0700";
      }
      {
        directory = "/var/cache/jellyfin";
        user = jellyfin.user;
        group = jellyfin.group;
        mode = "0700";
      }
    ];
  }

  (mkIf cfg.reverseProxy.enable {
    requirements = [ "services.caddy" ];

    ns.services.caddy.virtualHosts.jellyfin = {
      inherit (cfg.reverseProxy) extraAllowedAddresses;
      extraConfig = ''
        reverse_proxy http://${cfg.reverseProxy.address}:8096
      '';
    };
  })

  (mkIf cfg.seerr.enable {
    asserts = [
      (cfg.enable && arr-stack.enable)
      "Seerr requires Jellyfin and the video torrent stack to be enabled"
    ];

    services.seerr = {
      enable = true;
      openFirewall = false;
      configDir =
        assert (
          lib.assertMsg (lib.versionOlder config.system.stateVersion "26.05") "Remove Seer config location override"
        );
        "/var/lib/seerr";
      port = cfg.seerr.port;
    };

    # Seer scan runs every 5 mins and pollutes the journal
    systemd.services.seerr.environment.LOG_LEVEL = "warning";
    systemd.services.seerr.serviceConfig.StateDirectory =
      assert (
        lib.assertMsg (lib.versionOlder config.system.stateVersion "26.05") "Remove Seer config location override"
      );
      mkForce "seerr";

    ns.services.caddy.virtualHosts.seerr = {
      inherit (cfg.seerr) extraAllowedAddresses;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.seerr.port}
      '';
    };

    ns.persistence.directories = singleton {
      directory = "/var/lib/private/seerr";
      user = "nobody";
      group = "nogroup";
      mode = "0755";
    };
  })
]
