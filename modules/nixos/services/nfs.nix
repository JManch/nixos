{
  lib,
  cfg,
  pkgs,
}:
let
  inherit (lib)
    mkIf
    mkForce
    listToAttrs
    elem
    filter
    concatStringsSep
    concatMapStringsSep
    mapAttrsToList
    concatMap
    attrNames
    filterAttrs
    mkEnableOption
    mkOption
    types
    ;
in
[
  {
    enableOpt = false;
    guardType = "custom";

    opts = {
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
                  type = with types; attrsOf str;
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
  }

  (mkIf (cfg.server.enable || cfg.client.enable) {
    environment.systemPackages = [ pkgs.nfs-utils ];
    boot.initrd.kernelModules = [ "nfs" ];
  })

  (mkIf cfg.server.enable {
    services.nfs = {
      server = {
        enable = true;
        exports =
          let
            # Filter shared fileSystems to those containing supported machines
            fileSystems = filter (f: f.clients != { }) (
              map (f: {
                inherit (f) path;
                clients = filterAttrs (machine: opts: elem machine cfg.server.supportedMachines) f.clients;
              }) cfg.server.fileSystems
            );

            uniqueMachines = lib.lists.unique (concatMap (f: attrNames f.clients) fileSystems);
          in
          ''
            # Unlike NFSv3, NFSv4 requires a root filesystem to be defined with
            # fsid=0 and all exported directories must be under the root
            /export ${concatMapStringsSep " " (m: "${m}(rw,fsid=0,nohide,no_subtree_check)") uniqueMachines}

            # Create export entries for every file system
            ${concatMapStringsSep "\n" (
              f:
              "/export/${f.path} ${
                concatStringsSep " " (mapAttrsToList (machine: opts: "${machine}(${opts})") f.clients)
              }"
            ) fileSystems}
          '';
      };

      settings = {
        # Disable NFSv3 to ensure NFSv4 is used. We prefer NFSv4 because
        # configuration is simpler and it's more secure. Don't need to open a
        # bunch of ports or run rpcbind service on server.
        nfsd = {
          UDP = "off";
          vers2 = "off";
          vers3 = "off";
        };
      };
    };

    # NFSv4 does not require rpcbind on the server
    services.rpcbind.enable = mkIf (!cfg.client.enable) (mkForce false);

    networking.firewall.allowedTCPPorts = [ 2049 ];

    programs.zsh.shellAliases.nfs-reload-exports = "sudo exportfs -arv";

    persistence.directories = [
      "/export"
      "/var/lib/nfs"
    ];
  })

  (
    let
      # Filter file systems to just those that this host supports
      fileSystems = filter (f: elem f.machine cfg.client.supportedMachines) cfg.client.fileSystems;
    in
    mkIf cfg.client.enable {
      boot.supportedFilesystems = [ "nfs" ];
      services.rpcbind.enable = true;

      # Need to do this as well
      systemd.tmpfiles.rules = map (f: "d /mnt/nfs/${f.path} 0775 ${f.user} ${f.group} - -") fileSystems;

      fileSystems = listToAttrs (
        map (f: {
          name = "/mnt/nfs/${f.path}";
          value = {
            device = "${f.machine}:/${f.path}";
            fsType = "nfs";
            options = f.options;
          };
        }) fileSystems
      );
    }
  )
]
