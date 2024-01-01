{ lib
, config
, username
, hostname
, ...
}:
let
  cfg = config.modules.services.syncthing;
  syncthingDir = "/var/lib/syncthing";

  devices = lib.attrsets.filterAttrs (h: _: h != hostname) {
    "ncase-m1" = {
      id = "HOHYHMW-A2QUJEL-NYOIKNF-GOQA5I5-NGDOLKH-BE5P7EP-T4RCN37-EE2FOA2";
      name = "NCASE-M1-NixOS";
      # WARN: This setting breaks new folder permissions in the current version
      # of syncthing. Folders that are auto accepted will have the permission
      # 700 no matter what. If you're using a dedicated syncthing user, this
      # makes them inaccessible from your normal user. I'm not sure if this is
      # a bug with syncthing or my own idiocy but for now I'm applying a patch
      # to syncthing that changes the default folder permission to 770.

      # Can't set this anyway cause need to be able to disable permissions of
      # newly added folders and the most reliable time to do this is when
      # adding them
      autoAcceptFolders = false;
    };
    "homelab" = {
      id = "YIEJ6FN-YOYO5V7-K4BXYDC-P26CQKL-SSV2P7Z-CORFJTZ-QIX2XSU-GMNVEAV";
      name = "HOMELAB";
      autoAcceptFolders = false;
    };
  };

  folders = {
    "notes" = {
      enable = cfg.shareNotes;
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
  # NOTE: Use the syncthing generate command for generating an initial key on
  # new deployments. Setup of a pre-configured deployment requires opening the
  # syncthing interface at http://localhost:8384, adding the shared folder and
  # enabling 'Ignore Permissions' under advanced settings.

  # https://nitinpassa.com/running-syncthing-as-a-system-user-on-nixos/ https://archive.is/BgIQt
  # WARN: Downside of this setup is that if I move files or folders into a sync
  # dir, their group will not automatically be updated and syncthing will not
  # track them. Can be worked around with some sort of time task.

  # Ideally the home-manager module would have feature-parity with the system
  # syncthing module, then I wouldn't have to mess with permissions.

  # So our user can access syncthing files
  users.users.${username}.extraGroups = [ "syncthing" ];
  systemd.services.syncthing.serviceConfig.UMask = "0007";
  systemd.tmpfiles.rules = [
    "d ${syncthingDir} 0750 ${username} syncthing"
  ];
  # For some reason I don't need to set gid flag?
  # systemd.tmpfiles.rules = lib.lists.map
  #   (folder: "d ${syncthingDir}/${folder} 2770 ${username} syncthing")
  #   (builtins.attrNames folders);

  # Load agenix cert and key for current host 
  age.secrets = {
    syncthingCert = {
      file = ../../../secrets/syncthing/${hostname}/cert.age;
      mode = "770";
      owner = "syncthing";
      group = "syncthing";
    };
    syncthingKey = {
      file = ../../../secrets/syncthing/${hostname}/key.age;
      mode = "770";
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
      overrideDevices = true;
      overrideFolders = true;
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
        directory = "/var/lib/syncthing";
        user = "syncthing";
        group = "syncthing";
        mode = "u=rwx,g=rwx,o=";
      }
    ];
  };
}
