{ pkgs, username }:
{
  ns.userPackages = [ pkgs.simple-scan ];

  nixpkgs.overlays = [
    (final: prev: {
      brscan4 = prev.brscan4.overrideAttrs (
        final': _: {
          version = "0.4.11-1";
          src = final.fetchurl {
            url = "https://download.brother.com/welcome/dlf105200/${final'.pname}-${final'.version}.amd64.deb";
            sha256 = "sha256-AntzZIcirIyOsanEGdKEplYsx2P+rJdAordaaDsJKXI=";
          };
        }
      );
    })
  ];

  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices."Brother-DCP-9015CDW" = {
        model = "DCP-9015CDW";
        ip = "10.30.30.15";
      };
    };
  };

  users.users.${username}.extraGroups = [ "scanner" ];
}
