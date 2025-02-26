{
  lib,
  args,
  inputs,
  config,
  username,
  hostname,
  adminUsername,
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkAliasOptionModule
    ;
  inherit (config.${ns}.system.virtualisation) vmVariant;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    (mkAliasOptionModule
      [ "hm" ]
      [
        "home-manager"
        "users"
        username
      ]
    )
    (mkAliasOptionModule
      [ "hmAdmin" ]
      [
        "home-manager"
        "users"
        adminUsername
      ]
    )
  ];

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
      inherit (args) self selfPkgs;
    };
  };
}
