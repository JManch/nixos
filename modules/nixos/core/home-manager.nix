{
  ns,
  lib,
  inputs,
  config,
  username,
  hostname,
  adminUsername,
  ...
}@args:
let
  inherit (lib) mkIf mkMerge;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  cfg = config.${ns}.core.homeManager;
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

  config = mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users = mkMerge [
        { ${username} = import ../../../homes/${hostname}.nix; }
        (mkIf (username != adminUsername) {
          ${adminUsername} = {
            ${ns} = {
              core.standalone = true;
              shell.enable = true;
              shell.promptColor = "purple";
              programs.git.enable = true;
              programs.neovim.enable = true;
            };
            home.stateVersion = config.home-manager.users.${username}.home.stateVersion;
          };
        })
      ];

      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit inputs hostname vmVariant;
        inherit (args)
          self
          selfPkgs
          ns
          ;
      };
    };
  };
}
