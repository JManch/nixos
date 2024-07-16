{
  lib,
  self,
  pkgs',
  inputs,
  config,
  username,
  hostname,
  adminUsername,
  ...
}:
let
  inherit (config.modules.system.virtualisation) vmVariant;
  cfg = config.modules.core.homeManager;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    (lib.mkAliasOptionModule [ "hm" ] [
      "home-manager"
      "users"
      username
    ])
    (lib.mkAliasOptionModule [ "hmAdmin" ] [
      "home-manager"
      "users"
      adminUsername
    ])
  ];

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users =
        {
          ${username} = import ../../../home/${hostname}.nix;
        }
        // lib.optionalAttrs (username != adminUsername) {
          ${adminUsername} = {
            modules = {
              core.standalone = true;
              shell.enable = true;
              shell.promptColor = "purple";
              programs.git.enable = true;
              programs.neovim.enable = true;
            };
            home.stateVersion = config.home-manager.users.${username}.home.stateVersion;
          };
        };

      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit
          inputs
          self
          hostname
          vmVariant
          pkgs'
          ;
      };
    };
  };
}
