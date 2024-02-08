{ lib
, osConfig
, ...
}:
lib.mkIf osConfig.modules.system.virtualisation.enable
{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
