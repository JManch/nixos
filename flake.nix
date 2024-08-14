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
        hasPrefix
        listToAttrs
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
          modules = [
            {
              nixpkgs.hostPlatform = system;
              nixpkgs.buildPlatform = "x86_64-linux";
            }
            ./hosts/${hostname}
            ./modules/nixos
          ];
        };
      };

      mkInstaller =
        name: system: base:
        let
          isIso = hasPrefix "cd-dvd" base;
        in
        {
          inherit name;
          value =
            (nixosSystem {
              specialArgs = {
                inherit
                  lib
                  self
                  base
                  isIso
                  ;
              };
              modules = [
                {
                  nixpkgs.hostPlatform = system;
                  nixpkgs.buildPlatform = "x86_64-linux";
                }
                ./hosts/installer
              ];
            }).config.system.build.${if isIso then "isoImage" else "sdImage"};
        };
    in
    {
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      packages = forEachSystem (
        pkgs:
        import ./pkgs { inherit pkgs; }
        // listToAttrs [
          (mkInstaller "installer-x86_64" "x86_64-linux" "cd-dvd/installation-cd-minimal.nix")
          (mkInstaller "installer-pi" "aarch64-linux" "sd-card/sd-image-aarch64.nix")
        ]
      );
      templates = import ./templates;

      nixosConfigurations = listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux")
        (mkHost "homelab" "joshua" "x86_64-linux")
        (mkHost "msi" "lauren" "x86_64-linux")
        (mkHost "pi-3" "joshua" "aarch64-linux")
      ];
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs.url = "git+file:///home/joshua/files/repos/nixpkgs";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    impermanence.url = "github:nix-community/impermanence";
    firstBoot.url = "github:JManch/false";
    vmInstall.url = "github:JManch/false";

    nix-colors.url = "github:misterio77/nix-colors";
    nix-colors.inputs.nixpkgs-lib.follows = "nixpkgs";

    # nix-resources.url = "git+file:///home/joshua/files/personal-repos/nix-resources";
    nix-resources.url = "git+ssh://git@github.com/JManch/nix-resources";
    nix-resources.inputs.nixpkgs.follows = "nixpkgs";

    neovim-config.url = "github:JManch/nvim";
    neovim-config.flake = false;

    anyrun.url = "github:Kirottu/anyrun";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";

    grimblast.url = "github:JManch/grimblast";
    grimblast.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hypridle.url = "github:hyprwm/hypridle";
    hypridle.inputs.nixpkgs.follows = "nixpkgs";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-gaming.inputs.nixpkgs.follows = "nixpkgs";
    nix-gaming.inputs.flake-parts.follows = "flake-parts";

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.inputs.pre-commit-hooks-nix.follows = "";
    lanzaboote.inputs.rust-overlay.follows = "rust-overlay";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    mint.url = "github:trumank/mint";
    mint.inputs.nixpkgs.follows = "nixpkgs";
    mint.inputs.rust-overlay.follows = "rust-overlay";

    cargo2nix.url = "github:cargo2nix/cargo2nix";
    cargo2nix.inputs.nixpkgs.follows = "nixpkgs";

    yaml2nix.url = "github:euank/yaml2nix";
    yaml2nix.inputs.nixpkgs.follows = "nixpkgs";
    yaml2nix.inputs.cargo2nix.follows = "cargo2nix";

    broadcast-box.url = "github:JManch/broadcast-box";
    broadcast-box.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    firefox-nightly.url = "github:nix-community/flake-firefox-nightly";
    firefox-nightly.inputs.nixpkgs.follows = "nixpkgs";
  };
}
