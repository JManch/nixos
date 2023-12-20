{ config, pkgs, ... }: {
  users.mutableUsers = false;
  users.users = {
    joshua = {
      isNormalUser = true;
      # TODO: Setup ssh keys
      openssh.authorizedKeys.keys = [ ];
      shell = pkgs.zsh;
      hashedPasswordFile = config.age.secrets.joshuaPasswd.path;
      extraGroups = ["wheel"];
    };
  };
}
