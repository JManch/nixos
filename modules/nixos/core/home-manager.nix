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
      [ ns "hm" ]
      [
        "home-manager"
        "users"
        username
      ]
    )
    (mkAliasOptionModule
      [ ns "hmNs" ]
      [
        "home-manager"
        "users"
        username
        ns
      ]
    )
    (mkAliasOptionModule
      [ ns "hmAdmin" ]
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
      { ${username} = ../../../homes/${hostname}.nix; }
      (mkIf (username != adminUsername) {
        ${adminUsername} = {
          ${ns}.programs.shell = {
            enable = true;
            promptColor = "purple";
            git.enable = true;
            neovim.enable = true;
            btop.enable = true;
          };
          home.stateVersion = config.${ns}.hm.home.stateVersion;
        };
      })
    ];

    sharedModules = [ ../../home-manager ];

    extraSpecialArgs = {
      inherit inputs hostname vmVariant;
      inherit (args) self sources;
    };
  };
}
