{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, username
, ...
}: {
  imports = [
    ./agenix.nix
    ./users.nix
    ./home-manager.nix
  ];

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    # Populates the nix registry with all our flake inputs `nix registry list`
    registry = (lib.mapAttrs (_: flake: { inherit flake; })) ((lib.filterAttrs (_: lib.isType "flake")) inputs);
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  # Add flake inputs to the system's legacy channels
  nix.nixPath = [ "/etc/nix/path" ];
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
      # cd here because I once had a bad experience where I accidentally built
      # in the nix store and it broke my entire install
      rebuild-switch = "cd && sudo nixos-rebuild switch --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-build = "cd && sudo nixos-rebuild build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-boot = "cd && sudo nixos-rebuild boot --flake /home/${username}/.config/nixos#${hostname}";
      inspect-nix-config = "nix --extra-experimental-features repl-flake repl '/home/${username}/.config/nixos#nixosConfigurations.${hostname}'";
    };
  };

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };

  time.timeZone = "Europe/London";
}
