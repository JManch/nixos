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
          inherit system;
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
            if (hasPrefix "installer" hostname) then
              [ ./hosts/installer ]
            else
              [
                ./hosts/${hostname}
                ./modules/nixos
              ];
        };
      };
    in
    {
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);
      packages = forEachSystem (pkgs: import ./pkgs { inherit pkgs; });
      templates = import ./templates;

      nixosConfigurations = listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux")
        (mkHost "homelab" "joshua" "x86_64-linux")
        (mkHost "msi" "lauren" "x86_64-linux")
        (mkHost "installer" "joshua" "x86_64-linux")
        (mkHost "installer-arm" "joshua" "aarch64-linux")
      ];
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1&rev=e4e84064f2d07810e0c150bce1369a0a00503e9a";
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
