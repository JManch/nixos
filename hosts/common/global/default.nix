{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./../../../modules/nixos
    ./security.nix
    ./networking.nix
    ./filesystem.nix
    ./agenix.nix
    ./ssh.nix
    ./impermanence.nix
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      joshua = import ../../../home/${config.networking.hostName}.nix;
    };
  };

  nixpkgs = {
    overlays = [
      (final: prev: {
        eza = prev.eza.overrideAttrs (oldAttrs: rec {
          version = "0.10.7";
          src = final.fetchFromGitHub {
            owner = "eza-community";
            repo = "eza";
            rev = "v${version}";
            hash = "sha256-f8js+zToP61lgmxucz2gyh3uRZeZSnoxS4vuqLNVO7c=";
          };

          cargoDeps = oldAttrs.cargoDeps.overrideAttrs (prev.lib.const {
            name = "eza-vendor.tar.gz";
            inherit src;
            outputHash = "sha256-OBsXeWxjjunlzd4q1B1NJTm8MrIjicep2KIkydACKqQ=";
          });
        });
      })
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake (I don't understand this)
    registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
  };

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  environment.systemPackages = [
    pkgs.git
  ];

  programs.zsh = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake ~/.config/nixos#${config.networking.hostName}";
    };
  };

  time.timeZone = "Europe/London";
}
