{
  description = "Joshua's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-colors.url = "github:misterio77/nix-colors";
    impermanence.url = "github:nix-community/impermanence";

    anyrun = {
      url = "github:Kirottu/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = {self, nixpkgs, home-manager, ... }@inputs:
  {
    # Desktop with both nixos and home manager configured
    # nixosConfigurations."ncase-m1" = nixpkgs.lib.nixosSystem {
    #   system = "x86_64-linux";
    #   specialArgs = { inherit inputs; };
    #   modules = [
    #     ./hosts/ncase-m1
    #     home-manager.nixosModules.home-manager
    #     {
    #       home-manager.useGlobalPkgs = true;
    #       home-manager.extraSpecialArgs = { inherit inputs; };
    #       home-manager.users.joshua = import ./home/ncase-m1.nix;
    #     }
    #   ];
    # };

    nixosConfigurations = {
      ncase-m1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/ncase-m1
        ];
      };
    };

    homeConfigurations = {
      "joshua@ncase-m1" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home/ncase-m1.nix
        ];
      };
    };

    # Macbook example with only home manager configured
    # homeConfigurations."joshua@macbook" = home-manager.lib.homeManagerConfiguration {
    #   pkgs = import nixpkgs { 
    #     system = "aarch64-darkwin";
    #     config = {
    #       allowUnfree = true;
    #     };
    #   };
    #   modules = [
    #     ./home/macbook.nix
    #   ];
    # };
  };
}
