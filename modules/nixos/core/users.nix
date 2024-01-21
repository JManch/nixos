{ lib
, pkgs
, config
, username
, ...
}:
{
  age.secrets.joshuaPasswd.file = ../../../secrets/passwds/joshua.age;
  users = {
    mutableUsers = false;
    users = {
      ${username} = {
        isNormalUser = true;
        shell = pkgs.zsh;
        password = lib.mkIf (config.device.type == "vm") "test";
        hashedPasswordFile = lib.mkIf (config.device.type != "vm") config.age.secrets.joshuaPasswd.path;
        extraGroups = [ "wheel" ];
      };
    };
  };
}
