lib: self:
let
  inherit (lib)
    listToAttrs
    mapAttrs'
    nameValuePair
    hasPrefix
    nixosSystem
    filterAttrs
    ;

  mkInstaller = name: system: base: {
    inherit name;
    value =
      (nixosSystem {
        specialArgs = {
          inherit
            lib
            self
            base
            ;
        };
        modules = [
          {
            nixpkgs.hostPlatform = system;
            nixpkgs.buildPlatform = "x86_64-linux";
          }
          ../hosts/installer
        ];
      }).config.system.build.isoImage;
  };

  piInstallers = mapAttrs' (
    name: value: nameValuePair "installer-${name}" value.config.system.build.sdImage
  ) (filterAttrs (n: _: hasPrefix "pi" n) self.nixosConfigurations);

in
listToAttrs [
  (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix")
]
// piInstallers
