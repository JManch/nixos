{ lib
, pkgs
, config
, username
, ...
}:
{
  users = {
    mutableUsers = false;
    users.${username} = {
      isNormalUser = true;
      shell = pkgs.zsh;
      hashedPasswordFile = config.age.secrets.joshuaPasswd.path;
      extraGroups = [ "wheel" ];
    };
  };

  virtualisation.vmVariant = {
    users.users.${username} = {
      # Password is "test"
      hashedPassword = "$y$jFT$zqu09q6g6PFap8WgDT4wv.$Yc.72WQcVGkA/gog4ogtdkrEhu3S0vRk3.teeAc09GB";
      hashedPasswordFile = lib.mkVMOverride null;
    };
  };
}
