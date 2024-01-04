{ lib
, nixosConfig
, ...
}:
lib.mkIf nixosConfig.modules.system.virtualisation.enable
{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
