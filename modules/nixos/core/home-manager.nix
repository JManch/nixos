{ lib
, self
, inputs
, config
, username
, hostname
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
  ];

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${username} = import ../../../home/${hostname}.nix;
      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit inputs self username hostname vmVariant;
      };
    };
  };
}
