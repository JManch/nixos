{ lib
, pkgs
, config
, inputs
, username
, ...
}:
let
  inherit (lib) utils mapAttrs filterAttrs isType mapAttrsToList;
in
{
  imports = utils.scanPaths ./.;

  environment.systemPackages = [ pkgs.git ];
  security.sudo.extraConfig = "Defaults lecture=never";
  time.timeZone = "Europe/London";
  system.stateVersion = "23.05";

  # Nice explanation of overlays: https://archive.is/f8goR
  #
  # My summary of the differences between overlays and `overrideAttrs`:
  #
  # Overlays modify the package derivation in nixpkgs whilst `overrideAttrs`
  # only modifies the package in the current context. In practice this means
  # that modifications made with overlays will apply to all instances of the
  # package throughout your entire configuration. If you want to modify a core
  # package that many modules and packages depend on, you can see how this is a
  # powerful feature. However, if not used carefully, overlays can trigger an
  # unwanted system-wide butterfly effect on package dependencies causing many
  # packages to be rebuilt from source. This is because modifying a package in
  # nixpkgs will result in all packages that depend on this package to have
  # their derivation modified and therefore their cache invalidated.
  #
  # `overrideAttrs` avoids this problem because the package is ONLY modified in
  # the context where you applied the override. This means that any dependent
  # packages will continue to use the unmodified version and will continue to
  # use the binary cache. If a module has a `package` option, this can be a
  # convenient place to apply the override as the package will be stored in the
  # option and can be easily reused elsewhere.
  #
  # In my experience, for the majority of packages that I'm overriding, only
  # overriding the package in the current context is sufficient. It has the
  # advantage of being more explicit than overlays and also guarantees no
  # unexpected dependency butterfly effects.
  #
  # Overlays allow for greater modifications to packages than `overrideAttrs`.
  # Literally anything is possible. The entire derivation can be replaced with
  # an entirely different package if desired. However, once again, in the vast
  # majority of cases this extra functionality is not required.
  #
  # To summarise, for the majority of situations where you want to modify a
  # package (using a different src, applying a patch etc...) overlays are NOT
  # necessary and `overrideAttrs` can be used instead. However depending on the
  # situation, overlays might be more convenient or required for their extra
  # functionality.
  nixpkgs = {
    overlays = [ ];
    config.allowUnfree = true;
  };

  nix =
    let
      flakeInputs = filterAttrs (_: isType "flake") inputs;
    in
    {
      channel.enable = false;

      # Populates the nix registry with all our flake inputs `nix registry list`
      # Enables referencing flakes with short name in nix commands 
      # e.g. 'nix shell n#dnsutils' or 'nix shell hyprland#wlroots-hyprland'
      registry = (mapAttrs (_: flake: { inherit flake; }) flakeInputs) // {
        self.flake = inputs.self;
        n.flake = inputs.nixpkgs;
      };

      # Add flake inputs to nix path. Enables loading flakes with <flake_name>
      # like how <nixpkgs> can be referenced.
      nixPath = mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      settings = {
        experimental-features = "nix-command flakes";
        auto-optimise-store = true;
        # Do not load the default global registry
        # https://channels.nixos.org/flake-registry.json
        flake-registry = "";
        # Fixes builds using --build-host
        trusted-users = [ username ];
        # Workaround for https://github.com/NixOS/nix/issues/9574
        nix-path = config.nix.nixPath;
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };
}
