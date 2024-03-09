{ pkgs, config, username, ... }:
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
}
