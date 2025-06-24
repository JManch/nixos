lib: self: pkgs:
let
  inherit (lib)
    listToAttrs
    mapAttrs'
    mapAttrs
    nameValuePair
    hasPrefix
    nixosSystem
    filterAttrs
    modules
    ;

  mkInstaller = name: system: base: {
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
          }
          (modules.importApply ../../hosts/installer { })
        ];
      }).config.system.build.isoImage.overrideAttrs
        (
          let
            tests = import ./tests.nix lib self name base pkgs;
          in
          {
            passthru.tests = mapAttrs (_: value: value.test) tests;
            passthru.testHosts = mapAttrs (_: value: value.testHost) tests;
          }
        );
  };

  piInstallers = mapAttrs' (
    name: value: nameValuePair "installer-${name}" value.config.system.build.sdImage
  ) (filterAttrs (n: _: hasPrefix "pi" n) self.nixosConfigurations);

in
listToAttrs [
  (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix")
]
// piInstallers
