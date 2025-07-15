lib: self: pkgs:
let
  inherit (lib)
    ns
    listToAttrs
    mapAttrs'
    mapAttrs
    nameValuePair
    hasPrefix
    filterAttrs
    modules
    mkBefore
    ;

  mkInstaller = name: system: base: {
    inherit name;
    value =
      let
        nixosSystem = (
          lib.nixosSystem {
            specialArgs = {
              hostname = "installer";
              inherit self base;
            };
            modules = [
              {
                nixpkgs.hostPlatform = system;
                nixpkgs.buildPlatform = "x86_64-linux";
                nixpkgs.overlays = mkBefore [ (_: prev: { ${ns} = import ../../pkgs self lib prev; }) ];
              }
              (modules.importApply ../../hosts/installer { })
            ];
          }
        );
      in
      nixosSystem.config.system.build.isoImage.overrideAttrs (
        let
          tests = import ./tests.nix lib self name base pkgs;
        in
        {
          passthru = {
            inherit nixosSystem;
            tests = mapAttrs (_: value: value.test) tests;
            testHosts = mapAttrs (_: value: value.testHost) tests;
          };
        }
      );
  };

  piInstallers = mapAttrs' (
    name: value: nameValuePair "installer-${name}" value.config.system.build.sdImage
  ) (filterAttrs (n: _: hasPrefix "pi" n) self.nixosConfigurations);

in
listToAttrs [
  (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix")
  (mkInstaller "installer-x86_64-latest-kernel" "x86_64-linux"
    "cd-dvd/installation-cd-minimal-new-kernel.nix"
  )
]
// piInstallers
