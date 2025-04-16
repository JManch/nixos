{
  lib,
  cfg,
  pkgs,
  config,
  username,
  adminUsername,
}:
let
  inherit (lib)
    mkOption
    types
    ns
    optional
    mkAliasOptionModule
    ;
in
{
  enableOpt = false;

  imports = [
    (mkAliasOptionModule
      [ ns "userPackages" ]
      [
        "users"
        "users"
        username
        "packages"
      ]
    )

    (mkAliasOptionModule
      [ ns "adminPackages" ]
      [
        "users"
        "users"
        adminUsername
        "packages"
      ]
    )
  ];

  opts = {
    username = mkOption {
      type = types.str;
      readOnly = true;
      default = username;
      description = "The username of the primary user of the nixosConfiguration";
    };

    adminUsername = mkOption {
      type = types.str;
      readOnly = true;
      default = "joshua";
      description = "The username of the admin user that exists on all hosts";
    };

    priviledgedUser = mkOption {
      type = types.bool;
      default = true;
      description = "Whether the host's primary user is part of the wheel group";
    };
  };

  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.zsh;
    users =
      {
        ${username} = {
          isNormalUser = true;
          description = lib.${ns}.upperFirstChar username; # displayed in GDM
          hashedPasswordFile = config.age.secrets."${username}Passwd".path;
          extraGroups = optional cfg.priviledgedUser "wheel";
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
