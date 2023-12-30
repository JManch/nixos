lib: {
  fetchers = import ./fetchers.nix lib;
  validators = import ./validators.nix lib;
  utils = import ./utils.nix lib;
}
