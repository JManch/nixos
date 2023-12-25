{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./../../../modules/nixos

    ./home-manager.nix
    ./networking.nix
    ./filesystem.nix
    ./agenix.nix
    ./ssh.nix
    ./impermanence.nix
    ./users.nix
    ./security.nix
  ];

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
    # Allows referring to flakes with nixpkgs#flake
    registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  # Add flake inputs to the system's legacy channels
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

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };

  fonts.enableDefaultPackages = true;

  time.timeZone = "Europe/London";
}
