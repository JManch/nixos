{
  description = "Joshua's NixOS Flake";

  outputs =
    { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib.extend (final: _: import ./lib self final "JManch");
      inherit (lib.${lib.ns}) forEachSystem mkHost mkDroidHost;
    in
    {
      templates = import ./templates;
      packages = forEachSystem (pkgs: import ./pkgs self lib pkgs);
      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);

      nixosConfigurations = lib.listToAttrs [
        (mkHost "ncase-m1" "joshua" "x86_64-linux" [ ])
        (mkHost "framework" "joshua" "x86_64-linux" [ ])
        (mkHost "homelab" "joshua" "x86_64-linux" [ ])
        (mkHost "msi" "lauren" "x86_64-linux" [ ])
        # (mkHost "pi-3" "joshua" "aarch64-linux" [ ])
        # (mkHost "surface-pro" "joshua" "x86_64-linux" [ ])
      ];

      nixOnDroidConfigurations = lib.listToAttrs [
        (mkDroidHost "pixel-9")
      ];
    };

  # To use a local flake as an input set url to "git+file://<PATH>"
  # To use a nixpkgs PR as an input set url to "github:NixOS/nixpkgs?ref=pull/<PR_NUMBER>/head"

  # To identify which inputs are causing evaluation warnings use NIX_ABORT_ON_WARN=1
  # with the --impure flag and inspect the stack trace

  # When locking a flake to a rev, it's important to manually run `nix flake
  # update <input>`; otherwise, the inputs of the locked flake will not be
  # updated https://github.com/NixOS/nix/issues/7860
  inputs = {
    # Critical inputs that provide imported NixOS modules or overlays. Ideally
    # should review changes after updating.

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    # Project dead? https://discourse.nixos.org/t/what-happened-to-raspberry-pi-nix/62417
    # raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    # raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    nixpkgs-xr.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs-xr.inputs.treefmt-nix.follows = "";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

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
    hypridle.inputs.hyprutils.follows = "hyprland/hyprutils";
    hypridle.inputs.hyprland-protocols.follows = "hyprland/hyprland-protocols";
    hypridle.inputs.hyprlang.follows = "hyprland/hyprlang";
    hypridle.inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";

    hyprlock.url = "github:hyprwm/hyprlock";
    hyprlock.inputs.nixpkgs.follows = "nixpkgs";
    hyprlock.inputs.hyprutils.follows = "hyprland/hyprutils";
    hyprlock.inputs.hyprgraphics.follows = "hyprland/hyprgraphics";
    hyprlock.inputs.hyprlang.follows = "hyprland/hyprlang";
    hyprlock.inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";

    hyprpolkitagent.url = "github:hyprwm/hyprpolkitagent";
    hyprpolkitagent.inputs.nixpkgs.follows = "nixpkgs";
    hyprpolkitagent.inputs.hyprutils.follows = "hyprland/hyprutils";

    hyprpaper.url = "github:hyprwm/hyprpaper";
    hyprpaper.inputs.nixpkgs.follows = "nixpkgs";
    hyprpaper.inputs.hyprutils.follows = "hyprland/hyprutils";
    hyprpaper.inputs.hyprgraphics.follows = "hyprland/hyprgraphics";
    hyprpaper.inputs.hyprlang.follows = "hyprland/hyprlang";
    hyprpaper.inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";

    hyprsunset.url = "github:hyprwm/hyprsunset";
    hyprsunset.inputs.nixpkgs.follows = "nixpkgs";
    hyprsunset.inputs.hyprland-protocols.follows = "hyprland/hyprland-protocols";
    hyprsunset.inputs.hyprutils.follows = "hyprland/hyprutils";
    hyprsunset.inputs.hyprlang.follows = "hyprland/hyprlang";
    hyprsunset.inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";

    nix-matlab.url = "gitlab:doronbehar/nix-matlab";
    nix-matlab.inputs.nixpkgs.follows = "nixpkgs";

    mint.url = "github:trumank/mint";

    broadcast-box.url = "github:JManch/broadcast-box/discord";
    broadcast-box.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    xdg-override.url = "github:koiuo/xdg-override";
    xdg-override.inputs.nixpkgs.follows = "nixpkgs";

    nvf.url = "github:JManch/nvf/blink-cmp-v1.7.0"; # do not override nixpkgs input for stability

    # Personal inputs

    firstBoot.url = "github:JManch/false";
    vmInstall.url = "github:JManch/false";

    nix-resources.url = "github:JManch/nix-resources"; # needs access-token configured to access
    nix-resources.inputs.nixpkgs.follows = "nixpkgs";
  };
}
