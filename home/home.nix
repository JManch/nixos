{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ../modules/home-manager
    inputs.nix-colors.homeManagerModules.default
    inputs.anyrun.homeManagerModules.default
  ];

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;

  font = {
    enable = true;
    family = "FiraCode Nerd Font";
    package = pkgs.nerdfonts.override {fonts = ["FiraCode"];};
  };

  home = {
    username = "joshua";
    homeDirectory = "/home/joshua";
  };

  home.packages = with pkgs; [
    neofetch
  ];

  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
