{ inputs, pkgs, lib, ... }: {

  imports = [
    ../modules/home-manager
    inputs.nix-colors.homeManagerModules.default
    inputs.anyrun.homeManagerModules.default
  ];

  nixpkgs = {
    overlays = [
      # add overlays here
    ];
    config = {
      allowUnfree = true;
    };
  };

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;

  home = {
    username = "joshua";
    homeDirectory = "/home/joshua";
  };

  home.packages = with pkgs; [
    neofetch
    spotify
    discord
  ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  programs.git.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
