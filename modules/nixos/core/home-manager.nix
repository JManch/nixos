{ lib
, self
, pkgs'
, inputs
, config
, username
, hostname
, adminUsername
, ...
}:
let
  cfg = config.modules.core.homeManager;
  inherit (config.modules.system.virtualisation) vmVariant;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" username ])
    (lib.mkAliasOptionModule [ "hmAdmin" ] [ "home-manager" "users" adminUsername ])
  ];

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users = {
        ${username} = import ../../../home/${hostname}.nix;
      } // lib.optionalAttrs (username != adminUsername) {
        ${adminUsername} = {
          modules = {
            shell.enable = true;
            programs.neovim.enable = true;
          };
        };
      };

      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit inputs self hostname vmVariant pkgs';
      };
    };
  };
}
