{
  inputs,
  pkgs,
  username,
  ...
}: {
  imports = [
    ../modules/home-manager
    inputs.nix-colors.homeManagerModules.default
  ];

  programs.home-manager.enable = true;
  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";
    packages = with pkgs; [
      fastfetch
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
