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

  programs.home-manager.enable = true;
  home = {
    username = "joshua";
    homeDirectory = "/home/joshua";
    packages = with pkgs; [
      neofetch
      unzip
      zip
      tree
      wget
    ];
  };

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;
  font = {
    enable = true;
    family = "FiraCode Nerd Font";
    package = pkgs.nerdfonts.override {fonts = ["FiraCode"];};
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
