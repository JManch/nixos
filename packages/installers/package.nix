{
  lib,
  self,
  scopePkgs,
}:
let
  inherit (lib)
    ns
    nixosSystem
    listToAttrs
    mapAttrs'
    nameValuePair
    hasPrefix
    filterAttrs
    mkBefore
    mkForce
    ;

  mkInstaller = name: system: base: extraConfig: {
    inherit name;
    value =
      (nixosSystem {
        specialArgs = {
          hostname = "installer";
          inherit self base;
        };
        modules = [
          {
            nixpkgs.hostPlatform = system;
            nixpkgs.buildPlatform = "x86_64-linux";
            nixpkgs.overlays = mkBefore [ (_: prev: { ${ns} = scopePkgs; }) ];
          }
          ./installer.nix
          extraConfig
        ];
      }).config.system.build.isoImage;
  };

  piInstallers = mapAttrs' (
    name: value: nameValuePair "installer-${name}" value.config.system.build.sdImage
  ) (filterAttrs (n: _: hasPrefix "pi" n) self.nixosConfigurations);

in
listToAttrs [
  (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix" { })
  (mkInstaller "installer-x86_64-latest-kernel" "x86_64-linux"
    "cd-dvd/installation-cd-minimal-new-kernel.nix"
    {
      boot.supportedFilesystems.zfs = mkForce false;
    }
  )
]
// piInstallers
