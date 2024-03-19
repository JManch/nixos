{ lib, username, ... }:
{
  imports = lib.utils.scanPaths ./.;

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

  # Reload systemd services on home-manager restart
  # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
  systemd.user.startServices = "sd-switch";
}
