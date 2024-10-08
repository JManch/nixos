{
  description = "Joshua's NixOS Flake";

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      ns = "JManch";
      systems = [ "x86_64-linux" ];
      lib = nixpkgs.lib.extend (final: _: (import ./lib final ns) // home-manager.lib);
      mkHost = lib.${ns}.mkHost self;
      forEachSystem = lib.${ns}.forEachSystem self systems;
    in
    {
      templates = import ./templates;
      packages = forEachSystem (pkgs: import ./pkgs ns lib pkgs self);

      nixosConfigurations = lib.listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux")
        (mkHost "homelab" "joshua" "x86_64-linux")
        (mkHost "msi" "lauren" "x86_64-linux")
        (mkHost "pi-3" "joshua" "aarch64-linux")
      ];
    };

  # To use a local flake as an input set url to "git+file://<PATH>"
  inputs = {
    # Critical inputs that provide imported NixOS modules or overlays. Ideally
    # should review changes after updating.

    nixpkgs.url = "github:JManch/nixpkgs/nixos-unstable-personal";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    impermanence.url = "github:nix-community/impermanence";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.inputs.pre-commit-hooks-nix.follows = "";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    vpn-confinement.inputs.nixpkgs.follows = "nixpkgs";

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

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hypridle.url = "github:hyprwm/hypridle";
    hypridle.inputs.nixpkgs.follows = "nixpkgs";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    mint.url = "github:JManch/mint";
    mint.inputs.nixpkgs.follows = "nixpkgs";

    broadcast-box.url = "github:JManch/broadcast-box";
    broadcast-box.inputs.nixpkgs.follows = "nixpkgs";

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
  };
}
