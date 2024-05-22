{ lib, pkgs, config, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkForce
    listToAttrs
    elem
    filter
    concatStringsSep
    mapAttrsToList
    concatMap
    attrNames
    filterAttrs;
  cfg = config.modules.services.nfs;
in
mkMerge [
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
            fileSystems = filter (f: f.clients != { }) (map
              (f: {
                inherit (f) path;
                clients = filterAttrs (machine: opts: elem machine cfg.server.supportedMachines) f.clients;
              })
              cfg.server.fileSystems);

            uniqueMachines = lib.lists.unique (concatMap (f: attrNames f.clients) fileSystems);
          in
          ''
            # Unlike NFSv3, NFSv4 requires a root filesystem to be defined with
            # fsid=0 and all exported directories must be under the root
            /export ${concatStringsSep " " (map (m: "${m}(rw,fsid=0,nohide,no_subtree_check)") uniqueMachines)}

            # Create export entries for every file system
            ${concatStringsSep "\n" (
              map (
                f: "/export/${f.path} ${concatStringsSep " " (
                  mapAttrsToList (machine: opts: "${machine}(${opts})") f.clients
                )}"
              )
              fileSystems)
            }
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
      fileSystems = filter
        (f: elem f.machine cfg.client.supportedMachines)
        cfg.client.fileSystems;
    in
    mkIf cfg.client.enable {
      boot.supportedFilesystems = [ "nfs" ];
      services.rpcbind.enable = true;

      # Need to do this as well
      systemd.tmpfiles.rules = map
        (f: "d /mnt/nfs/${f.path} 0775 ${f.user} ${f.group}")
        fileSystems;

      fileSystems = listToAttrs (map
        (f: {
          name = "/mnt/nfs/${f.path}";
          value = {
            device = "${f.machine}:/${f.path}";
            fsType = "nfs";
            options = f.options;
          };
        })
        fileSystems);
    }
  )
]
