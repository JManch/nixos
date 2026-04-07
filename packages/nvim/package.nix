{
  lib,
  self,
  pkgs,
  sources,
}:
(self.inputs.nvf.lib.neovimConfiguration {
  # For maximum stability, rather than using our flake's primary nixpkgs pin,
  # use the nixpkgs revision pinned to nvf. This way we avoid breakages when
  # nixpkgs-unstable changes something e.g.
  # https://github.com/NotAShelf/nvf/issues/1312
  # pkgs = self.inputs.nvf.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  pkgs =
    assert lib.assertMsg (
      self.inputs.nvf.inputs.nixpkgs.rev == "46db2e09e1d3f113a13c0d7b81e2f221c63b8ce9"
    ) "Remove nvf nixpkgs override";
    pkgs;

  extraSpecialArgs = {
    inherit sources;
  };

  modules = [
    ./core
    ./plugins
  ];
}).neovim
