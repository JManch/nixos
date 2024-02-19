{ pkgs, config, username, ... }:
{
  age.secrets.joshuaPasswd.file = ../../../secrets/passwds/joshua.age;

  users = {
    mutableUsers = false;
    users.${username} = {
      isNormalUser = true;
      shell = pkgs.zsh;
      hashedPasswordFile = config.age.secrets.joshuaPasswd.path;
      extraGroups = [ "wheel" ];
    };
  };
}
