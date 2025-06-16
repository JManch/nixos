{
  pkgs,
  self,
  sources,
}:
self.inputs.nvf.lib.neovimConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit sources;
  };

  modules = [
    ./core
    ./plugins
  ];
}
