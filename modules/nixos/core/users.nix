{ lib
, pkgs
, config
, username
, ...
}: {
  age.secrets.joshuaPasswd.file = ../../../secrets/passwds/joshua.age;
  users = {
    mutableUsers = false;
    users = {
      ${username} = {
        isNormalUser = true;
        shell = pkgs.zsh;
        password = lib.mkIf (config.device.type == "vm") "test";
        hashedPasswordFile = lib.mkIf (config.device.type != "vm") config.age.secrets.joshuaPasswd.path;
        # TODO: Change authorized keys to all other hosts
        openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMd4QvStEANZSnTHRuHg0edyVdRmIYYTcViO9kCyFFt7 JManch@protonmail.com" ];
        extraGroups = [ "wheel" ];
      };
    };
  };
}
