{
  description = "Joshua's NixOS Flake";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib.extend (final: _: import ./lib final "JManch");
      inherit (lib.${lib.ns}.flakeUtils self) forEachSystem mkHost mkDroidHost;
    in
    {
      templates = import ./templates;
      packages = forEachSystem (pkgs: import ./pkgs lib pkgs self);

      nixosConfigurations = lib.listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux")
        (mkHost "homelab" "joshua" "x86_64-linux")
        (mkHost "msi" "lauren" "x86_64-linux")
        (mkHost "pi-3" "joshua" "aarch64-linux")
      ];

      nixOnDroidConfigurations = lib.listToAttrs [
        (mkDroidHost "pixel-5")
      ];
    };

  # To use a local flake as an input set url to "git+file://<PATH>"

  # When locking a flake to a rev, it's important to manually run `nix flake
  # update <input>`; otherwise, the inputs of the locked flake will not be
  # updated https://github.com/NixOS/nix/issues/7860
  inputs = {
    # Critical inputs that provide imported NixOS modules or overlays. Ideally
    # should review changes after updating.

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-broadcast-box.url = "github:JManch/nixpkgs/broadcast-box";

    impermanence.url = "github:nix-community/impermanence";

    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-on-droid.url = "github:nix-community/nix-on-droid";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.home-manager.follows = "home-manager";

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

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-xr.inputs.treefmt-nix.follows = "";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Inputs that provide imported home-manager modules

    nix-colors.url = "github:misterio77/nix-colors";
    nix-colors.inputs.nixpkgs-lib.follows = "nixpkgs";

    gnome-keybinds.url = "github:JManch/hm-gnome-keybinds";
    gnome-keybinds.inputs.nixpkgs.follows = "nixpkgs";

    # Inputs that provide packages

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    hyprland-plugins.url = "github:hyprwm/hyprland-plugins";
    hyprland-plugins.inputs.hyprland.follows = "hyprland";

    hypridle.url = "github:hyprwm/hypridle";
    hypridle.inputs.nixpkgs.follows = "nixpkgs";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";

    hyprpolkitagent.url = "github:hyprwm/hyprpolkitagent";
    hyprpolkitagent.inputs.nixpkgs.follows = "nixpkgs";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    mint.url = "github:JManch/mint";
    mint.inputs.nixpkgs.follows = "nixpkgs";

    broadcast-box.url = "github:JManch/broadcast-box";
    broadcast-box.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs-unstable.follows = "nixpkgs";

    # Locked to avoid broken auto formatting
    neovim.url = "github:nix-community/neovim-nightly-overlay?rev=973f6526dd30053a7ef98017272207af00bd615b";
    neovim.inputs.nixpkgs.follows = "nixpkgs";

    recyclarr-templates.url = "github:recyclarr/config-templates";
    recyclarr-templates.flake = false;

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
