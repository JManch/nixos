{ lib
, inputs
, pkgs
, config
, osConfig
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable {
  modules.desktop.font = {
    family = "BerkeleyMono Nerd Font";
    package = inputs.nix-resources.packages.${pkgs.system}.berkeley-mono-nerdfont;
  };
  fonts.fontconfig.enable = true;
  home.packages = [ config.modules.desktop.font.package ];
}
