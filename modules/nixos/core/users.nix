{ lib
, pkgs
, config
, username
, adminUsername
, ...
}:
let
  inherit (lib) optional;
  inherit (config.modules.core) priviledgedUser;
in
{
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
    users = {
      ${username} = {
        isNormalUser = true;
        hashedPasswordFile = config.age.secrets."${username}Passwd".path;
        extraGroups = optional priviledgedUser "wheel";
      };
    } // lib.optionalAttrs (username != adminUsername) {
      ${adminUsername} = {
        uid = 1; # use 1 because it matches wheel group and is unused
        isSystemUser = true;
        useDefaultShell = true;
        createHome = true;
        home = "/home/${adminUsername}";
        hashedPasswordFile = config.age.secrets."${adminUsername}Passwd".path;
        group = "wheel";
      };
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
