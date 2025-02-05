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
    ns
    mkEnableOption
    mkOption
    optionals
    types
    mkAliasOptionModule
    attrNames
    mkDefault
    ;
  cfg = config.${ns}.services;
in
{
  imports = lib.${ns}.scanPaths ./. ++ [
    (mkAliasOptionModule
      [ "backups" ]
      [
        ns
        "services"
        "restic"
        "backups"
      ]
    )
  ];

  options.${ns}.services = {
    udisks.enable = mkEnableOption "udisks";
    lact.enable = mkEnableOption "Lact";
    index-checker.enable = mkEnableOption "Google Site Index Checker";
    unifi.enable = mkEnableOption "Unifi Controller";
    fail2ban.enable = mkEnableOption "Fail2ban";
    acme.enable = mkEnableOption "ACME";
    postgresql.enable = mkEnableOption "Postgresql";

    wireguard =
      let
        wgInterfaceOptions = {
          enable = mkEnableOption "the wireguard interface";
          autoStart = mkEnableOption "auto start";
          routerPeer = mkEnableOption "my router as a peer";

          address = mkOption {
            type = types.str;
            default = null;
            example = "10.0.0.2/24";
            description = "Assigned IP address for this device on the VPN along with the subnet mask";
          };

          listenPort = mkOption {
            type = with types; nullOr port;
            default = null;
            example = "51820";
            description = ''
              Optional port for Wireguard to listen on. Useful on for static
              clients that need a reliable VPN connection (persistent keep
              alive can be temperamental). If set, will open the port in the
              firewall and disable persistent keep alive. Note that this
              client's peers must manually specify the endpoint address and
              port.
            '';
          };

          subnet = mkOption {
            type = types.int;
            default = null;
            example = "24";
            description = "Subnet of the wireguard network";
          };

          routerAllowedIPs = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "List of allowed IPs for router peer";
          };

          peers = mkOption {
            type = with types; listOf attrs;
            default = [ ];
            description = "Wireguard peers";
          };

          dns = {
            enable = mkEnableOption "a custom DNS server for the VPN";
            host = mkEnableOption "hosting the custom DNS server on this host";

            domains = mkOption {
              type = with types; attrsOf str;
              default = { };
              example = {
                "example.com" = "10.0.0.4";
              };
              description = ''
                Attribute set of domains mapped to addresses. If systemd
                resolved is used the DNS server associated with this VPN will
                not longer be the default route. Instead, the configured
                domains will be added as DNS routing rules (in this case the
                address does not matter). This means that only DNS requests to
                these domains will be routed through the custom DNS server
                configured for the VPN.

                If `dns.host` is enabled, DNS redirect rules mapping domains to
                their addresses will be added to the DNS server.
              '';
            };

            address = mkOption {
              type = types.str;
              default = null;
              description = "Address of the device hosting the DNS server inside the VPN";
            };

            port = mkOption {
              type = types.nullOr types.port;
              default = null;
              description = "Port for the DNS server to listen on";
            };
          };
        };
      in
      mkOption {
        default = { };
        type = types.attrsOf (types.submodule { options = wgInterfaceOptions; });
        description = "Wireguard VPN interfaces";
      };

    wgnord = {
      enable = mkEnableOption "Wireguard NordVPN";
      confinement.enable = mkEnableOption "Confinement Wireguard NordVPN";

      excludeSubnets = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of subnets to exclude from being routed through the VPN. Does
          not apply to the confinement VPN.
        '';
      };

      country = mkOption {
        type = types.str;
        default = "Switzerland";
        description = "The country to VPN to";
      };
    };

    air-vpn = {
      enable = mkEnableOption "Wireguard AirVPN";
      confinement.enable = mkEnableOption "Confinement Wireguard AirVPN";
    };

    jellyfin = {
      enable = mkEnableOption "Jellyfin";
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
          shows = "/home/${username}/videos/shows";
          movies = "/home/${username}/videos/movies";
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

    ollama = {
      enable = mkEnableOption "Ollama";
      autoStart = mkEnableOption "autostart";

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for Ollama to be exposed on.
        '';
      };
    };

    broadcast-box = {
      enable = mkEnableOption "Broadcast Box";
      autoStart = mkEnableOption "Broadcast Box service auto start";
      proxy = mkEnableOption ''
        publically exposing Broadcast Box with a reverse proxy.
      '';

      allowedAddresses = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of address to give access to Broadcast Box.
        '';
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for Broadcast Box to be exposed on.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Webserver listening port";
      };

      udpMuxPort = mkOption {
        type = types.port;
        default = 3000;
        description = "UDP port used for streaming";
      };
    };

    caddy = {
      enable = mkEnableOption "Caddy";

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for Caddy to be exposed on.
        '';
      };

      trustedAddresses = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [
          "192.168.89.2/32"
          "192.168.88.0/24"
        ];
        description = ''
          List of address ranges representing the trusted local network. Use in
          combination with allowAddresses to restrict access to virtual hosts.
        '';
      };

      extraFail2banTrustedAddresses = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          Caddy fail2ban filter addresses to trust in addition to trusted
          addresses. Does not affect virtual host access.
        '';
      };

      goAccessExcludeIPRanges = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of address ranges excluded from go access using their strange
          format.
        '';
      };

      virtualHosts = mkOption {
        type = types.attrsOf (
          types.submodule (
            { config, ... }:
            {
              options = {
                forceHttp = mkEnableOption ''
                  forcing the virtual host to use HTTP instead of HTTPS
                '';

                allowTrustedAddresses =
                  mkEnableOption ''
                    access to this virtual host from all trusted address as
                    configured with `caddy.trustedAddresses`
                  ''
                  // {
                    default = true;
                  };

                extraAllowedAddresses = mkOption {
                  type = with types; listOf str;
                  default = [ ];
                  description = ''
                    Extra addresses in addition to the trusted address (assuming
                    `allowTrustedAddresses` is enabled) to give access to this
                    virtual host.
                  '';
                };

                allowedAddresses = mkOption {
                  type = with types; listOf str;
                  readOnly = true;
                  default =
                    (optionals config.allowTrustedAddresses cfg.caddy.trustedAddresses) ++ config.extraAllowedAddresses;
                };

                extraConfig = mkOption {
                  type = types.lines;
                  default = null;
                  description = ''
                    Extra config to append to the virtual host, like the upstream
                    option
                  '';
                };
              };
            }
          )
        );
        default = { };
        description = ''
          Wrapper for Caddy virtual host config that configures DNS ACME and
          remote IP address blocking.
        '';
      };
    };

    dns-stack = {
      enable = mkEnableOption ''
        a DNS stack using Ctrld and dnsmasq. Intended for use on server
        devices to provide DNS services on a network.
      '';
      enableIPv6 = mkEnableOption "IPv6 DNS responses";
      debug = mkEnableOption "verbose logs for debugging";

      listenPort = mkOption {
        type = types.port;
        default = 53;
        description = "Listen port for DNS requests";
      };

      ctrldListenPort = mkOption {
        type = types.port;
        default = 5354;
        description = "Listen port for the internal Ctrld DNS server";
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for dnsmasq to be exposed on.
        '';
      };

      routerAddress = mkOption {
        type = types.str;
        default = null;
        description = ''
          Local IP address of the router that internal DDNS queries should be
          pointed to.
        '';
      };

      dnsmasqConfig = mkOption {
        type = types.attrs;
        readOnly = true;
        description = "Dnsmasq settings";
      };

      generateDnsmasqConfig = mkOption {
        type = types.functionTo (types.functionTo types.pathInStore);
        readOnly = true;
        description = "Internal function for generate dnsmasq config from attrset";
      };
    };

    frigate = {
      enable = mkEnableOption "Frigate";

      coral = {
        enable = mkEnableOption "Google Coral Accelerator";
        type = mkOption {
          type = types.enum [
            "pci"
            "usb"
          ];
          description = "Coral device type";
        };
      };

      rtspAddress = mkOption {
        type = types.functionTo types.str;
        default = _: "";
        description = ''
          Function accepting channel and subtype that returns the RTSP address string.
        '';
      };

      nvrAddress = mkOption {
        type = types.str;
        default = "";
        description = ''
          IP address of the NVR on the local network.
        '';
      };

      webrtc = {
        enable = (mkEnableOption "WebRTC streams with Go2RTC") // {
          default = true;
        };

        port = mkOption {
          type = types.port;
          default = 8555;
        };
      };
    };

    mosquitto = {
      enable = mkEnableOption "Mosquitto MQTT Broker";
      explorer.enable = mkEnableOption "MQTT Explorer";

      users = mkOption {
        type = types.attrs;
        default = { };
        example = lib.literalExpression ''
          {
            frigate = {
              acl = [ "readwrite #" ];
              hashedPasswordFile = mqttFrigatePassword.path;
            };
          }
        '';
      };

      tlsUsers = mkOption {
        type = types.attrs;
        default = { };
        example = lib.literalExpression ''
          {
            frigate = {
              acl = [ "readwrite #" ];
              hashedPasswordFile = mqttFrigatePassword.path;
            };
          }
        '';
      };
    };

    calibre = {
      enable = mkEnableOption "Calibre E-book Manager";

      port = mkOption {
        type = types.port;
        default = 8083;
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

    vaultwarden = {
      enable = mkEnableOption "Vaultwarden";
      adminInterface = mkEnableOption "admin interface. Keep disabled and enable when needed.";

      port = mkOption {
        type = types.port;
        default = 8222;
      };

      extraAllowedAddresses = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of address to give access to Vaultwarden in addition to the
          trusted list.
        '';
      };
    };

    zigbee2mqtt = {
      enable = mkEnableOption "Zigbee2MQTT";

      mqtt = {
        user = mkEnableOption "Zigbee2mqtt Mosquitto user";
        tls = mkEnableOption "TLS Mosquitto user";

        server = mkOption {
          type = types.str;
          default = "mqtt://127.0.0.1:1883";
          description = "MQTT server address";
        };
      };

      proxy = {
        enable = mkEnableOption "proxying Zigbee2mqtt";

        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Frontend proxy address";
        };

        port = mkOption {
          type = types.port;
          default = cfg.zigbee2mqtt.port;
          description = "Frontend proxy port";
        };
      };

      port = mkOption {
        type = types.port;
        default = 8084;
        description = "Port of the frontend web interface";
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address for the frontend web interface to listen on";
      };

      deviceNode = mkOption {
        type = types.str;
        example = "/dev/ttyUSB0";
        description = "The device node of the zigbee adapter.";
      };
    };

    scrutiny = {
      collector.enable = mkEnableOption ''
        the Scrutiny collector service. The collector service sends data to the
        web server and can run on any machine that can access the web server.
      '';

      server = {
        enable = mkEnableOption "hosting the Scrutiny web server";

        port = mkOption {
          type = types.port;
          default = 8085;
          description = "Listen port of the web server";
        };
      };
    };

    torrent-stack = {
      video.enable = mkEnableOption "Video torrent stack";
      music.enable = mkEnableOption "Music torrent stack";

      mediaDir = mkOption {
        type = types.str;
        default = "/data/media";
        description = ''
          Absolute path to directory where torrent downloads and media library
          will be stored.
        '';
      };
    };

    nfs = {
      server = {
        enable = mkEnableOption "NFS server";

        supportedMachines = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of machines that this host can share NFS exports with.
          '';
        };

        fileSystems = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                path = mkOption {
                  type = types.str;
                  example = "jellyfin";
                  description = "Export path relative to /export";
                };

                clients = mkOption {
                  type = types.attrsOf types.str;
                  example = {
                    "homelab.lan" = "ro,no_subtree_check";
                  };
                  description = ''
                    Attribute set of client machine names associated with a comma
                    separated list of NFS export options
                  '';
                };
              };
            }
          );
          default = [ ];
          example = [
            {
              path = "jellyfin";
              clients = {
                "homelab.lan" = "ro,no_subtree_check";
                "192.168.88.254" = "ro,no_subtree_check";
              };
            }
          ];
          description = "List of local file systems that are exported by the NFS server";
        };
      };

      client = {
        enable = mkEnableOption "NFS client";

        supportedMachines = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = "List of machines this host can accept NFS file systems from";
        };

        fileSystems = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                path = mkOption {
                  type = types.str;
                  example = "jellyfin";
                  description = "Mount path relative to /mnt/nfs";
                };

                machine = mkOption {
                  type = types.str;
                  description = "NFS machine identifier according to exports(5)";
                };

                user = mkOption {
                  type = types.str;
                  description = "User owning the mounted directory";
                };

                group = mkOption {
                  type = types.str;
                  description = "Group owning the mounted directory";
                };

                options = mkOption {
                  type = with types; listOf str;
                  default = [
                    "x-systemd.automount"
                    "noauto"
                    "x-systemd.idle-timeout=600"
                  ];
                  description = "List of options for the NFS file system";
                };
              };
            }
          );
          default = [ ];
          example = [
            {
              name = "jellyfin";
              machine = "homelab.lan";
              user = "jellyfin";
              group = "jellyfin";
            }
          ];
          description = "List of remote NFS file systems to mount";
        };
      };
    };

    wallabag = {
      enable = mkEnableOption "Wallabag";

      port = mkOption {
        type = types.port;
        default = 8088;
        description = "Port for the Wallabag server to listen on";
      };
    };

    restic = {
      enable = mkEnableOption "Restic backups";
      runMaintenance = mkEnableOption "repo maintenance after performing backups" // {
        default = true;
      };

      backups = mkOption {
        type = types.attrsOf (
          types.submodule {
            freeformType = types.attrsOf types.anything;
            options = {
              preBackupScript = mkOption {
                type = types.lines;
                default = "";
                description = "Script to run before backing up";
              };

              postBackupScript = mkOption {
                type = types.lines;
                default = "";
                description = "Script to run after backing up";
              };

              restore = {
                pathOwnership = mkOption {
                  type = types.attrsOf (
                    types.submodule {
                      options = {
                        user = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = ''
                            User to set restored files to. If null, user will not
                            be changed. Useful for modules that do not have static
                            IDs https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix.
                          '';
                        };

                        group = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = ''
                            Group to set restored files to. If null, group will not
                            be changed.
                          '';
                        };
                      };
                    }
                  );
                  default = { };
                  description = ''
                    Attribute for assigning ownership user and group for each
                    backup path.
                  '';
                };

                removeExisting = mkOption {
                  type = types.bool;
                  default = true;
                  description = ''
                    Whether to delete all files and directories in the backup
                    paths before restoring backup.
                  '';
                };

                preRestoreScript = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Script to run before restoring the backup";
                };

                postRestoreScript = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Script to run after restoring the backup";
                };
              };

            };
          }
        );
        default = { };
        apply =
          # Modify the backup paths and ownership paths to include persistence
          # path if impermanence is enabled and merge with home manager backups

          # WARN: Exclude and include paths are not prefixed with persistence
          # to allow non-absolute patterns, be careful with those
          backups:
          let
            inherit (lib)
              ns
              optionalAttrs
              mapAttrs'
              mapAttrs
              nameValuePair
              optionalString
              ;
            inherit (config.${ns}.core) homeManager;
            inherit (config.${ns}.system) impermanence;
            homeBackups = optionalAttrs homeManager.enable config.hm.${ns}.backups;
          in
          mapAttrs (
            name: value:
            value
            // {
              paths = map (path: "${optionalString impermanence.enable "/persist"}${path}") value.paths;
              restore = value.restore // {
                pathOwnership = mapAttrs' (
                  path: value: nameValuePair "${optionalString impermanence.enable "/persist"}${path}" value
                ) value.restore.pathOwnership;
              };
            }
          ) (backups // homeBackups);
        description = ''
          Attribute set of Restic backups matching the upstream module backups
          options.
        '';
      };

      backupSchedule = mkOption {
        type = types.str;
        default = "*-*-* 05:30:00";
        description = "Backup service default OnCalendar schedule";
      };

      server = {
        enable = mkEnableOption "Restic REST server";

        dataDir = mkOption {
          type = types.str;
          description = "Directory where the restic repository is stored";
          default = "/var/backup/restic";
        };

        remoteCopySchedule = mkOption {
          type = types.str;
          default = "*-*-* 05:30:00";
          description = "OnCalendar schedule when local repo is copied to cloud";
        };

        remoteMaintenanceSchedule = mkOption {
          type = types.str;
          default = "Sun *-*-* 06:00:00";
          description = "OnCalendar schedule to perform maintenance on remote repo";
        };

        port = mkOption {
          type = types.port;
          default = 8090;
          description = "Port for the Restic server to listen on";
        };
      };
    };

    minecraft-server =
      let
        availablePlugins =
          (import ../../../pkgs/minecraft-plugins { inherit lib pkgs; }).minecraft-plugins
          // inputs.nix-resources.packages.${pkgs.system}.minecraft-plugins;
        jsonFormat = pkgs.formats.json { };
      in
      {
        enable = mkEnableOption "Minecraft server";

        mshConfig = mkOption {
          type = jsonFormat.type;
          apply = jsonFormat.generate "msh-config.json";
          description = "Minecraft server hibernation config";
        };

        memory = mkOption {
          type = types.int;
          default = 4000;
          description = "Memory allocation in megabytes for the Minecraft server";
        };

        interfaces = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of additional interfaces for the Minecraft server to be
            exposed on.
          '';
        };

        extraAllowedAddresses = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of address to give access to virtual hosts in addition to the
            trusted list.
          '';
        };

        port = mkOption {
          type = types.port;
          default = 25565;
          description = ''
            The actual server listens on `port - 1` and the server hibernator
            listens on this port.
          '';
        };

        plugins = mkOption {
          type = types.listOf (types.enum (attrNames availablePlugins));
          default = [ ];
          description = "List of plugin packages to install on the server";
        };

        files = mkOption {
          type = types.attrsOf (
            types.submodule {
              options = {
                value = mkOption {
                  type = types.nullOr types.lines;
                  default = null;
                  description = "Lines of text to copy into target config file";
                };

                diff = mkOption {
                  type = types.nullOr types.lines;
                  default = null;
                  description = ''
                    Diff file to be applied to reference config file. Use diff -u
                    to generate diff.
                  '';
                };

                reference = mkOption {
                  type = types.nullOr types.pathInStore;
                  default = null;
                  description = "Reference config file that diff is applied to";
                };
              };
            }
          );
          default = { };
          description = ''
            Attribute set where keys are paths to files relative to the dataDir
            and values are files contents"
          '';
        };
      };

    beammp-server = {
      enable = mkEnableOption "BeamMP Server";
      openFirewall = mkEnableOption "opening the firewall";

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable BeamMP Server autostart";
      };

      port = mkOption {
        type = types.port;
        default = 30814;
        description = "Port for the BeamMP Server to listen on";
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for BeamMP Server to be exposed on.
        '';
      };
    };

    mikrotik-backup = {
      enable = mkEnableOption "Mikrotik Backup";

      routerAddress = mkOption {
        type = types.str;
        default = "router.lan";
        description = "Address of the router to fetch backup files from";
      };
    };

    mealie = {
      enable = mkEnableOption "Mealie";

      port = mkOption {
        type = types.port;
        default = 9000;
        description = "Port for the Mealie server to listen on";
      };
    };

    taskchampion-server = {
      enable = mkEnableOption "Taskchampion Sync Server";

      port = mkOption {
        type = types.port;
        default = 10222;
        description = "Port for the Taskchampion server to listen on";
      };
    };

    factorio-server = {
      enable = mkEnableOption "Factorio Server";

      port = mkOption {
        type = types.port;
        default = 34197;
        description = "Port for the Factorio server to listen on";
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for the Factorio server to be exposed
          on
        '';
      };
    };

    satisfactory-server = {
      enable = mkEnableOption "Satisfactory Dedicated Server";
      openFirewall = mkEnableOption "opening the firewall on default interfaces";
      autoStart = mkEnableOption "automatic server start";

      port = mkOption {
        type = types.port;
        default = 7777;
        description = "Port for the Satisfactory server to listen on";
      };

      interfaces = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = ''
          List of additional interfaces for the Satisfactory server to be
          exposed on
        '';
      };
    };

    file-server = {
      enable = mkEnableOption "File sharing server";

      uploadAlias = {
        enable = mkEnableOption "shell alias for uploading files";
        serverAddress = mkOption {
          type = types.str;
          description = "File server address to use in alias";
        };
      };

      allowedAddresses = mkOption {
        type = with types; listOf str;
        default = [ ];
        description = "List of address to give access to the file server";
      };
    };

    navidrome = {
      enable = mkEnableOption "Navidrome";

      musicDir = mkOption {
        type = types.str;
        description = "Absolute path to music library";
      };
    };
  };

  config = {
    services.udisks2.enable = mkDefault cfg.udisks.enable;

    # Allows user services like home-manager syncthing to start on boot and
    # keep running rather than stopping and starting with each ssh session on
    # servers
    users.users.${username}.linger = config.${ns}.device.type == "server";

    programs.zsh.shellAliases = {
      sys = "systemctl";
      sysu = "systemctl --user";
    };
  };
}
