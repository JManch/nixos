{ lib
, config
, username
, hostname
, pkgs
, ...
}:
let
  cfg = config.modules.services.syncthing;
  syncthingDir = "/var/lib/syncthing";
  mountServiceName = (builtins.replaceStrings [ "/" ] [ "-" ] (builtins.substring 1 ((builtins.stringLength syncthingDir) - 1) syncthingDir)) + ".mount";
  isNotServer = (config.device.type != "server");

  devices = lib.attrsets.filterAttrs (h: _: h != hostname) {
    "ncase-m1" = {
      id = "HOHYHMW-A2QUJEL-NYOIKNF-GOQA5I5-NGDOLKH-BE5P7EP-T4RCN37-EE2FOA2";
      name = "NCASE-M1-NixOS";
      # This option would be nice but we can't use it because there's no way to
      # declaratively configure shared folders we recieve. This just auto
      # accepts the folders with some default settings. Also, it forces shared
      # folders to have 700 permission mask which makes accessing shared files
      # from our own user impossible.
      autoAcceptFolders = false;
    };
    "homelab" = {
      id = "YIEJ6FN-YOYO5V7-K4BXYDC-P26CQKL-SSV2P7Z-CORFJTZ-QIX2XSU-GMNVEAV";
      name = "HOMELAB";
    };
  };

  folders = {
    "notes" = {
      enable = cfg.server;
      path = "${syncthingDir}/notes";
      ignorePerms = true;
      # Share to all other devices
      devices = builtins.attrNames devices;
      versioning = {
        type = "staggered";
        params = {
          cleanInterval = "3600";
          maxAge = "31536000";
        };
      };
    };
  };
in
lib.mkIf (cfg.enable) {

  # --- Deployment Instructions ---
  # 1. For a new device, generate cert and key with `syncthing generate` then
  # add to agenix.
  # 2. Open http://localhost:8384 and add shared folders with staggered version
  # and ignore permissions enabled.

  # If the device is a server, syncthing files will not be accessible from the
  # main user account.
  # If the device is not a server, we apply a bunch of permission rules to
  # ensure that files and directories created in shared folders belong to group
  # 'syncthing' and have a 777 group permission mask. That way our main user
  # can create files in shared folders and syncthing will be able to access
  # them.

  # WARN: Downside of this setup is that if I move files or folders into a
  # synced dir, their group will not automatically be updated and syncthing
  # will not track them. Can be worked around with some sort of scheduled
  # systemd task that updates permissions.

  # Add main user to the syncthing group
  users.users.${username}.extraGroups = lib.mkIf isNotServer [ "syncthing" ];
  systemd.services.syncthing = lib.mkMerge [
    {
      # Ensure syncthing service starts after persist bind mount
      after = [ "${mountServiceName}" ];
      requires = [ "${mountServiceName}" ];
    }
    (lib.mkIf isNotServer {
      serviceConfig = {
        UMask = "0007";
        # https://serverfault.com/questions/349145/can-i-override-my-umask-using-acls-to-make-all-files-created-in-a-given-director
        # Set ACL on shared folders (tip: manually remove acl with setfacl -b -d DIR)
        # This ensure that any directories or files created in shared folders will have full syncthing group permissions
        # (the + ensures the command runs as root even though the service runs as the syncthing user)
        ExecStartPost = "+${
          lib.concatStringsSep ";"
          (lib.lists.map (folder: "${pkgs.acl}/bin/setfacl -d -m mask:07 /persist${syncthingDir}/${folder}") (builtins.attrNames folders))
        }";
      };
    })
  ];

  # Attempt to fix old config not merging
  systemd.services.syncthing-init = {
    after = [ "${mountServiceName}" ];
    requires = [ "${mountServiceName}" ];
  };

  systemd.tmpfiles.rules = lib.mkIf isNotServer (
    # Apply setgid bit on shared folders
    # This ensures that any directories or files created in shared folders will be part of the syncthing group
    (lib.lists.map
      (folder: "d /persist${syncthingDir}/${folder} 2770 ${username} syncthing")
      (builtins.attrNames folders))
    # Apply access permissions to root share folder
    ++ [ "d /persist${syncthingDir} 0750 ${username} syncthing" ]
  );

  # Load agenix cert and key for current host 
  age.secrets = {
    syncthingCert = {
      file = ../../../secrets/syncthing/${hostname}/cert.age;
      mode = "400";
      owner = "syncthing";
      group = "syncthing";
    };
    syncthingKey = {
      file = ../../../secrets/syncthing/${hostname}/key.age;
      mode = "400";
      owner = "syncthing";
      group = "syncthing";
    };
  };

  services.syncthing = {
    enable = true;
    cert = config.age.secrets.syncthingCert.path;
    key = config.age.secrets.syncthingKey.path;
    relay.enable = true;
    dataDir = "${syncthingDir}";
    openDefaultPorts = true;
    settings = {
      overrideDevices = !isNotServer;
      # Disable this on non-servers as the folder has to be manually added
      overrideFolders = !isNotServer;
      devices = devices;
      folders = folders;
      options = {
        urAccepted = -1;
      };
    };
  };

  environment.persistence."/persist" = {
    directories = [
      {
        directory = syncthingDir;
        user = "syncthing";
        group = "syncthing";
        mode = "u=rwx,g=rwx,o=";
      }
    ];
  };
}
