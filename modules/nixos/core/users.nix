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
      # WARN: Ever since https://github.com/linux-pam/linux-pam/pull/784 there
      # is a delay after entering the username during login. Because I use a
      # strongly hashing algorithm it's quite noticeable.
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
