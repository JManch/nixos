{
  self,
  pkgs,
}:
self.inputs.nvf.lib.neovimConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    hmConfig = self.nixosConfigurations.ncase-m1.config.JManch.hm;
  };
  modules = [
    ./core
    ./plugins
  ];
}
