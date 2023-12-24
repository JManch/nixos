{username, ...}: {
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.users."${username}".extraGroups = ["libvirtd"];

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/libvirt"
    ];
  };
}
