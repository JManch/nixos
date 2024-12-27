{
  lib,
  pkgs,
  config,
  username,
  adminUsername,
  ...
}:
let
  inherit (lib) ns optional;
  inherit (config.${ns}.core) priviledgedUser;
in
{
  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
    users =
      {
        ${username} = {
          isNormalUser = true;
          description = lib.${ns}.upperFirstChar username; # displayed in GDM
          hashedPasswordFile = config.age.secrets."${username}Passwd".path;
          extraGroups = optional priviledgedUser "wheel";
        };
      }
      // lib.optionalAttrs (username != adminUsername) {
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
      password = "test";
      hashedPasswordFile = lib.mkVMOverride null;
    };
  };
}
