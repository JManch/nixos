{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mapAttrs mapAttrs' filterAttrs isType;
in
{
  imports = lib.utils.scanPaths ./.;

  programs.zsh.enable = true;
  environment.systemPackages = [ pkgs.git ];
  time.timeZone = "Europe/London";
  system.stateVersion = "23.05";

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config.allowUnfree = true;
  };

  nix = {
    # Populates the nix registry with all our flake inputs `nix registry list`
    registry = (mapAttrs (_: flake: { inherit flake; })) ((filterAttrs (_: isType "flake")) inputs)
      // { n.flake = inputs.nixpkgs; };

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
    mapAttrs'
      (name: value: {
        name = "nix/path/${name}";
        value.source = value.flake;
      })
      config.nix.registry;

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };
}
