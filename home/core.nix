{ inputs
, pkgs
, config
, username
, ...
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
      unzip
      zip
      tree
      wget
    ];
  };

  xdg.userDirs = {
    enable = true;
    desktop = "${config.home.homeDirectory}/desktop";
    documents = "${config.home.homeDirectory}/documents";
    download = "${config.home.homeDirectory}/downloads";
    music = "${config.home.homeDirectory}/music";
    pictures = "${config.home.homeDirectory}/pictures";
    videos = "${config.home.homeDirectory}/videos";
  };

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;
  modules.desktop.font = {
    family = "FiraCode Nerd Font";
    package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
