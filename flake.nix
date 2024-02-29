{
  description = "Joshua's NixOS Flake";

  inputs = {
    # NOTE: Use the `nix flake metadata <flake_url>` command to check if a
    # flake needs nixpkgs.follows defined
    # Update individual inputs using `nix flake lock --update-input <INPUT_NAME>`
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "git+file:///home/joshua/repos/nixpkgs?ref=nixos-unstable-personal";
    nix-colors.url = "github:misterio77/nix-colors";
    impermanence.url = "github:nix-community/impermanence";

    nix-resources.url = "git+ssh://git@github.com/JManch/nix-resources";
    # nix-resourcesurl = "git+file:///home/joshua/repos/nix-resources";
    nix-resources.inputs.nixpkgs.follows = "nixpkgs";

    anyrun.url = "github:Kirottu/anyrun";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";

    # home-manager.url = "github:nix-community/home-manager";
    home-manager.url = "git+file:///home/joshua/repos/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

    spicetify.url = "github:the-argus/spicetify-nix";
    spicetify.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-gaming.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.inputs.nixpkgs.follows = "nixpkgs";

    hypridle.url = "github:hyprwm/hypridle";
    hypridle.inputs.nixpkgs.follows = "nixpkgs";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";
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

      nixosConfigurations = {
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

        virtual = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            hostname = "virtual";
            inherit inputs outputs username lib;
          };
          modules = [
            ./modules/nixos
            ./hosts/virtual
          ];
        };
      };
    };
}
