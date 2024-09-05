{
  description = "Joshua's NixOS Flake";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-small,
      home-manager,
      ...
    }@inputs:
    let
      inherit (lib)
        nixosSystem
        genAttrs
        filterAttrs
        nameValuePair
        hasPrefix
        listToAttrs
        optionals
        ;

      lib = nixpkgs.lib.extend (final: prev: (import ./lib final) // home-manager.lib);

      systems = [ "x86_64-linux" ];
      forEachSystem =
        f:
        genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      mkHost = hostname: username: system: {
        name = hostname;
        value = nixosSystem {
          specialArgs = {
            inherit
              self
              inputs
              hostname
              username
              lib
              ;
            selfPkgs = self.packages.${system};
            pkgs' = import nixpkgs-small {
              inherit system;
              config.allowUnfree = true;
            };
          };
          modules =
            [
              {
                nixpkgs.hostPlatform = system;
                nixpkgs.buildPlatform = "x86_64-linux";
              }
              ./hosts/${hostname}
              ./modules/nixos
            ]
            ++ optionals (hasPrefix "pi" hostname) [
              # Raspberry-pi-nix does not have an enable option so we have to
              # conditionally import like this
              inputs.raspberry-pi-nix.nixosModules.raspberry-pi
              ./modules/nixos/hardware/raspberry-pi.nix
            ];
        };
      };

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
              ./hosts/installer
            ];
          }).config.system.build.isoImage;
      };
    in
    {
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      templates = import ./templates;

      packages = forEachSystem (
        pkgs:
        import ./pkgs { inherit pkgs; }
        // listToAttrs [
          (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix")
        ]
        // lib.mapAttrs' (
          name: value: nameValuePair "installer-${name}" value.config.system.build.sdImage
        ) (filterAttrs (n: _: hasPrefix "pi" n) self.nixosConfigurations)
      );

      nixosConfigurations = listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux")
        (mkHost "homelab" "joshua" "x86_64-linux")
        (mkHost "msi" "lauren" "x86_64-linux")
        (mkHost "pi-3" "joshua" "aarch64-linux")
      ];
    };

  # To use a local flake as an input set url to "git+file://<PATH>"
  inputs = {
    # Critical inputs that provide imported NixOS modules. Ideally should
    # review changes after updating.

    nixpkgs.url = "github:JManch/nixpkgs/nixos-unstable-personal";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    impermanence.url = "github:nix-community/impermanence";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.inputs.pre-commit-hooks-nix.follows = "";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";
    raspberry-pi-nix.inputs.rpi-firmware-nonfree-src.follows = "rpi-firmware-nonfree-src";

    rpi-firmware-nonfree-src.url = "github:RPi-Distro/firmware-nonfree/bookworm";
    rpi-firmware-nonfree-src.flake = false;

    # Inputs that provide imported home-manager modules

    nix-colors.url = "github:misterio77/nix-colors";
    nix-colors.inputs.nixpkgs-lib.follows = "nixpkgs";

    ags.url = "github:Aylur/ags";
    ags.inputs.nixpkgs.follows = "nixpkgs";

    # Inputs that provide packages

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hypridle.url = "github:hyprwm/hypridle";
    hypridle.inputs.nixpkgs.follows = "nixpkgs";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    mint.url = "github:trumank/mint";
    mint.inputs.nixpkgs.follows = "nixpkgs";

    yaml2nix.url = "github:euank/yaml2nix";
    yaml2nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # Personal inputs

    firstBoot.url = "github:JManch/false";
    vmInstall.url = "github:JManch/false";

    nix-resources.url = "git+ssh://git@github.com/JManch/nix-resources";
    nix-resources.inputs.nixpkgs.follows = "nixpkgs";

    neovim-config.url = "github:JManch/nvim";
    neovim-config.flake = false;

    grimblast.url = "github:JManch/grimblast";
    grimblast.inputs.nixpkgs.follows = "nixpkgs";

    broadcast-box.url = "github:JManch/broadcast-box";
    broadcast-box.inputs.nixpkgs.follows = "nixpkgs";
  };
}
