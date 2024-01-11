{ lib
, pkgs
, config
, username
, ...
}:
lib.mkIf config.modules.system.virtualisation.enable {
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.users."${username}".extraGroups = [ "libvirtd" ];

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/libvirt"
    ];
  };
}
