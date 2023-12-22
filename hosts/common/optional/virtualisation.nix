{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  users.users."joshua".extraGroups = [ "libvirtd" ];
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
}
