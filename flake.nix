{
  description = "Joshua's NixOS Flake";

  inputs = {
    # NOTE: Use the `nix flake metadata <flake_url>` command to check if a
    # flake needs nixpkgs.follows defined
    # Update individual inputs using `nix flake lock --update-input <INPUT_NAME>`

    nixpkgs.url = "github:JManch/nixpkgs/nixos-unstable-personal";
    # nixpkgs.url = "git+file:///home/joshua/repos/nixpkgs?ref=nixos-unstable-personal";
    impermanence.url = "github:nix-community/impermanence";
    firstBoot.url = "github:JManch/false";

    nix-colors.url = "github:misterio77/nix-colors";
    nix-colors.inputs.nixpkgs-lib.follows = "nixpkgs";

    # nix-resources.url = "git+file:///home/joshua/repos/nix-resources";
    nix-resources.url = "git+ssh://git@github.com/JManch/nix-resources";
    nix-resources.inputs.nixpkgs.follows = "nixpkgs";

    anyrun.url = "github:Kirottu/anyrun";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";

    grimblast.url = "github:JManch/grimblast";
    grimblast.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

    hyprland.url = "github:hyprwm/Hyprland?rev=72e31d3335982382c289302a41f7144009c5c82f";
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

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay?rev=58d367a1924bf0d02bcc5bd2c5af8ac97f178381";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Provides home assistant heatmiser component
    graham33.url = "github:graham33/nur-packages?rev=71fcef3f3f0f198577fee51f64a0f3711daefc99";
    graham33.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... } @ inputs:
    let
      inherit (self) outputs;
      systems = [ "x86_64-linux" ];
      username = "joshua";

      mkLib = nixpkgs:
        nixpkgs.lib.extend
          (final: prev: (import ./lib final) // home-manager.lib);

      lib = mkLib nixpkgs;

      forEachSystem = f:
        nixpkgs.lib.genAttrs systems (system:
          f (nixpkgs.legacyPackages.${system}));
    in
    {
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      packages = forEachSystem (pkgs: import ./pkgs { inherit pkgs; });
      templates = import ./templates;

      nixosConfigurations = {

        installer = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs outputs username lib;
          };
          modules = [
            ./hosts/installer
          ];
        };

        ncase-m1 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            hostname = "ncase-m1";
            inherit inputs outputs username lib;
          };
          modules = [
            ./modules/nixos
            ./hosts/ncase-m1
          ];
        };

        homelab = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            hostname = "homelab";
            inherit inputs outputs username lib;
          };
          modules = [
            ./modules/nixos
            ./hosts/homelab
          ];
        };
      };
    };
}
