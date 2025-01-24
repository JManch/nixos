{
  lib,
  inputs,
  config,
  username,
  hostname,
  adminUsername,
  ...
}@args:
let
  inherit (lib) ns mkIf mkMerge;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  cfg = config.${ns}.core.homeManager;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    (lib.mkAliasOptionModule
      [ "hm" ]
      [
        "home-manager"
        "users"
        username
      ]
    )
    (lib.mkAliasOptionModule
      [ "hmAdmin" ]
      [
        "home-manager"
        "users"
        adminUsername
      ]
    )
  ];

  config = mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users = mkMerge [
        { ${username} = import ../../../homes/${hostname}.nix; }
        (mkIf (username != adminUsername) {
          ${adminUsername} = {
            ${ns}.programs.shell = {
              enable = true;
              promptColor = "purple";
              git.enable = true;
              neovim.enable = true;
              btop.enable = true;
            };
            home.stateVersion = config.hm.home.stateVersion;
          };
        })
      ];

      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit inputs hostname vmVariant;
        inherit (args)
          self
          selfPkgs
          ;
      };
    };
  };
}
