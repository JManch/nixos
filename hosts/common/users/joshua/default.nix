{
  config,
  pkgs,
  lib,
  ...
}: {
  users.mutableUsers = false;
  users.users = {
    joshua = {
      isNormalUser = true;
      shell = pkgs.zsh;
      initialHashedPassword = "$y$jFT$Rkz7TzHZjMUgbEwnWPB8V0$nM9cf5w99RCGuc9M8lFynwD2KYOnn9vSzui990k/cN7";
      hashedPasswordFile = config.age.secrets.joshuaPasswd.path;
      openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com"];
      extraGroups = ["wheel"];
    };
  };
}
