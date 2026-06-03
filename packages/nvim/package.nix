{
  self,
  pkgs,
  sources,
}:
(self.inputs.nvf.lib.neovimConfiguration {
  # For maximum stability, rather than using our flake's primary nixpkgs pin,
  # use the nixpkgs revision pinned to nvf. This way we avoid breakages when
  # nixpkgs-unstable changes something e.g.
  # https://github.com/NotAShelf/nvf/issues/1312
  pkgs = import self.inputs.nvf.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  extraSpecialArgs = {
    inherit sources;
  };

  modules = [
    ./core
    ./plugins
    {
      vim.pluginOverrides = {
        # nvf is quite slow with updating blink
        blink-cmp = pkgs.vimPlugins.blink-cmp.overrideAttrs {
          # need this package name otherwise pack load fails
          pname = "blink-cmp";
        };
      };
    }
  ];
}).neovim
