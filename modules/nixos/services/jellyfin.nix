# WARN: It's important to close the webpage when casting from Jellyfin to
# external clients such as jellyfin-mpv-shim or a TV. This is because the
# Jellyfin client that started the cast will request a large chunk of metadata
# every couple of seconds (presumably to update the cast progress bar?). With
# multiple clients watching this can easily throttle the web server and make
# Jellyfin unusable.
{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkMerge
    optional
    mkForce
    optionalString
    mapAttrsToList
    genAttrs
    attrNames;
  inherit (config.modules.system.networking) publicPorts;
  inherit (config.modules.services) caddy wireguard;
  inherit (config.services) jellyfin;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.jellyfin;
  uid = 1500;
  gid = 1500;

  # Patched jellyfin-web to fix a bug in jellyfin-apiclient-javascript that
  # caused Android logins to fail when using a reverse proxy
  # I think it's somewhat to this issue https://github.com/jellyfin/jellyfin-android/issues/742
  jellyfin-web = pkgs.jellyfin-web.overrideAttrs (oldAttrs: rec {
    patches = (oldAttrs.patches or [ ]) ++ [ ../../../patches/jellyfin-web.patch ];
    npmDeps = pkgs.fetchNpmDeps {
      inherit (oldAttrs) src;
      inherit patches;
      hash = "sha256-49cHlscStoef0kvB0X/Fpphwe51uIV2ZlLswHo/3K+Y=";
    };
  });
in
mkMerge [
  {
    modules.system.reservedIDs.jellyfin = {
      inherit uid gid;
    };
  }

  (mkIf cfg.enable
    {
      environment.systemPackages = optional cfg.mediaPlayer pkgs.jellyfin-media-player;

      services.jellyfin = {
        enable = true;
        package = pkgs.jellyfin.overrideAttrs (oldAttrs: {
          preInstall = ''
            makeWrapperArgs+=(
              --add-flags "--ffmpeg ${pkgs.ffmpeg}/bin/ffmpeg"
              --add-flags "--webdir ${jellyfin-web}/share/jellyfin-web"
            )
          '';
        });
        openFirewall = cfg.openFirewall;
      };

      users.users.jellyfin.uid = uid;
      users.groups.jellyfin.gid = gid;

      systemd.services.jellyfin = {
        wantedBy = mkForce (optional cfg.autoStart "multi-user.target");

        serviceConfig = {
          # Bind mount home media directories so jellyfin can access them
          BindReadOnlyPaths = mapAttrsToList
            (name: dir: "${dir}:/var/lib/jellyfin/media${optionalString (name != "") "/${name}"}")
            cfg.mediaDirs;
          SocketBindDeny = publicPorts;
        };
      };

      networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
        allowedTCPPorts = [ 8096 8920 ];
        allowedUDPPorts = [ 1900 7359 ];
      });

      # Jellyfin module has good default hardening

      systemd.tmpfiles.rules = map
        (name: "d /var/lib/jellyfin/media${optionalString (name != "") "/${name}"} 0700 ${jellyfin.user} ${jellyfin.group}")
        (attrNames cfg.mediaDirs);

      backups.jellyfin = {
        paths = [ "/var/lib/jellyfin" ];
        exclude = [ "transcodes" "media" "log" "metadata" ];
        restore = {
          preRestoreScript = "sudo systemctl stop jellyfin";
          pathOwnership = {
            "/var/lib/jellyfin" = { user = "jellyfin"; group = "jellyfin"; };
          };
        };
      };

      persistence.directories = [
        {
          directory = "/var/lib/jellyfin";
          user = jellyfin.user;
          group = jellyfin.group;
          mode = "700";
        }
        {
          directory = "/var/cache/jellyfin";
          user = jellyfin.user;
          group = jellyfin.group;
          mode = "700";
        }
      ];

      persistenceHome.directories = mkIf cfg.mediaPlayer [
        ".local/share/Jellyfin Media Player"
        ".local/share/jellyfinmediaplayer"
      ];
    }
  )

  (mkIf cfg.reverseProxy.enable {
    assertions = utils.asserts [
      caddy.enable
      "Jellyfin reverse proxy requires caddy to be enabled"
    ];

    services.caddy.virtualHosts."jellyfin.${fqDomain}".extraConfig = ''
      import ${if wireguard.friends.enable then "wg-friends" else "lan"}-only
      reverse_proxy http://${cfg.reverseProxy.address}:8096
    '';
  })
]
