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
      password = lib.mkVMOverride "test";
      hashedPasswordFile = lib.mkVMOverride null;
    };
  };
}
