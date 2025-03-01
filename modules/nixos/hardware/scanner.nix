{ pkgs, username }:
{
  userPackages = [ pkgs.simple-scan ];

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
