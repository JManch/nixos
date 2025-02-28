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
    attrNames
    attrValues
    mapAttrsToList
    optionalString
    singleton
    length
    hasPrefix
    splitString
    concatLines
    all
    mkEnableOption
    types
    mkOption
    ;
  inherit (lib.${ns}) asserts;
  inherit (config.${ns}.system) impermanence;
  inherit (config.${ns}.services) caddy torrent-stack;
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

      mediaDirs = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          shows = "/home/joshua/videos/shows";
          movies = "/home/joshua/videos/movies";
        };
        description = ''
          Attribute set of media directories that will be bind mount to
          /var/lib/jellyfin/media. Attribute name is target bind path relative
          to media dir and value is absolute source dir.
        '';
      };

      jellyseerr = {
        enable = mkEnableOption "Jellyseerr behind a reverse proxy";

        port = mkOption {
          type = types.port;
          default = 5055;
          description = "Jellyseerr listening port";
        };
      };
    };

    asserts = [
      (all (n: n != "") (attrNames cfg.mediaDirs))
      "Jellyfin media dir target cannot be empty"
      (all (n: (length (splitString "/" n)) == 1) (attrNames cfg.mediaDirs))
      "Jellyfin media dir target cannot be a subdir"
      (all (n: !hasPrefix "/persist" n) (attrValues cfg.mediaDirs))
      "Jellyfin media dirs should NOT be prefixed with /persist"
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
              map (plugin: ''cp --no-preserve=mode -r ${plugin}/* /var/lib/jellyfin/plugins '') cfg.plugins
            )}
          '';

      serviceConfig = {
        StateDirectory = "jellyfin";
        CacheDirectory = "jellyfin";
        StateDirectoryMode = "0700";
        ProtectSystem = "strict";
      };
      wantedBy = mkForce (optional cfg.autoStart "multi-user.target");
    };

    systemd.mounts = mapAttrsToList (target: source: {
      what = (optionalString impermanence.enable "/persist") + source;
      where = "/var/lib/jellyfin/media/${target}";
      bindsTo = [ "jellyfin.service" ];
      requiredBy = [ "jellyfin.service" ];
      before = [ "jellyfin.service" ];
      options = "bind,ro";
      mountConfig.DirectoryMode = "0700";
    }) cfg.mediaDirs;

    systemd.tmpfiles.rules = [
      "d /var/lib/jellyfin/media 0700 jellyfin jellyfin - -"
    ];

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

    backups.jellyfin = mkIf cfg.backup {
      paths = [ "/var/lib/jellyfin" ];
      exclude = [
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

    persistence.directories = [
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
    assertions = asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    ${ns}.services.caddy.virtualHosts.jellyfin = {
      inherit (cfg.reverseProxy) extraAllowedAddresses;
      extraConfig = ''
        reverse_proxy http://${cfg.reverseProxy.address}:8096
      '';
    };
  })

  (mkIf cfg.jellyseerr.enable {
    assertions = asserts [
      (cfg.enable && torrent-stack.video.enable)
      "Jellyseerr requires Jellyfin and the video torrent stack to be enabled"
    ];

    users.groups.jellyseerr = { };
    users.users.jellyseerr = {
      group = "jellyseerr";
      isSystemUser = true;
    };

    services.jellyseerr = {
      enable = true;
      openFirewall = false;
      port = cfg.jellyseerr.port;
    };

    systemd.services.jellyseerr = {
      # Jellyseer scan runs every 5 mins and pollutes the journal
      environment.LOG_LEVEL = "warning";
      serviceConfig = {
        User = "jellyseerr";
        Group = "jellyseerr";
      };
    };

    ${ns}.services.caddy.virtualHosts.jellyseerr.extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.jellyseerr.port}
    '';

    persistence.directories = singleton {
      directory = "/var/lib/private/jellyseerr";
      user = "jellyseerr";
      group = "jellyseerr";
      mode = "0750";
    };
  })
]
