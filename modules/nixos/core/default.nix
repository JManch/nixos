{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, username
, ...
}: {
  imports = lib.utils.scanPaths ./.;

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
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
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

  environment.systemPackages = with pkgs; [
    git
    nurl # tool for generating nix fetcher calls from urls
  ];

  programs.zsh = {
    enable = true;
    shellAliases = {
      rebuild-switch = "sudo nixos-rebuild switch --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-test = "sudo nixos-rebuild test --flake /home/${username}/.config/nixos#${hostname}";
      # cd here because I once had a bad experience where I accidentally built
      # in the nix store and it broke my entire install
      rebuild-build = "cd && nixos-rebuild build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-boot = "sudo nixos-rebuild boot --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-vm = "cd && nixos-rebuild build-vm --flake /home/${username}/.config/nixos#virtual";
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
