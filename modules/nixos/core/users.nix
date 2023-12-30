{ config
, pkgs
, username
, ...
}: {
  users.mutableUsers = false;
  users.users = {
    ${username} = {
      isNormalUser = true;
      shell = pkgs.zsh;
      hashedPasswordFile = config.age.secrets.joshuaPasswd.path;
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com" ];
      extraGroups = [ "wheel" ];
    };
  };
}
