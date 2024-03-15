{ config, inputs, username, ... }:
{
  imports = [
    ../modules/home-manager
    inputs.nix-colors.homeManagerModules.default
    inputs.agenix.homeManagerModules.default
  ];

  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/${username}_ed25519" ];

  programs.home-manager.enable = true;

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "23.05";
  };

  persistence.directories = [
    "downloads"
    "pictures"
    "music"
    "videos"
    "repos"
    "files"
    ".config/nixos"
    ".cache/nix"
    ".local/share/systemd" # needed for persistent user timers to work properly
  ];

  colorscheme = inputs.nix-colors.colorSchemes.ayu-mirage;

  # Reload systemd services on home-manager restart
  # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
  systemd.user.startServices = "sd-switch";
}
