{ pkgs
, config
, inputs
, username
, ...
}: {
  imports = [
    ../modules/home-manager
    inputs.nix-colors.homeManagerModules.default
    inputs.agenix.homeManagerModules.default
  ];

  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/${username}_ed25519" ];

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

  impermanence.directories = [
    "downloads"
    "pictures"
    "music"
    "videos"
    "repos"
    "files"
    ".config/nixos"
    ".cache/nix"
  ];

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;
  # base00: "#171B24"
  # base01: "#1F2430"
  # base02: "#242936"
  # base03: "#707A8C"
  # base04: "#8A9199"
  # base05: "#CCCAC2"
  # base06: "#D9D7CE"
  # base07: "#F3F4F5"
  # base08: "#F28779"
  # base09: "#FFAD66"
  # base0A: "#FFD173"
  # base0B: "#D5FF80"
  # base0C: "#95E6CB"
  # base0D: "#5CCFE6"
  # base0E: "#D4BFFF"
  # base0F: "#F29E74"

  # Reload systemd services on home-manager restart
  # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
  systemd.user.startServices = "sd-switch";
  home.stateVersion = "23.05";
}
