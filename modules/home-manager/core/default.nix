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
    "files"
    ".config/nixos"
    ".cache/nix"
    ".local/share/systemd" # needed for persistent user timers to work properly
  ];

  backups = {
    nixos = {
      paths = [ ".config/nixos" ];
      restore.removeExisting = true;
    };

    files = {
      paths = [ "files" ];
      exclude =
        let
          absPath = "/persist/home/${username}";
        in
        [
          "${absPath}/files/games"
          "${absPath}/files/repos"
          "${absPath}/files/software"
          "${absPath}/files/remote-builds"
        ];
    };
  };

  # Reload systemd services on home-manager restart
  # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
  systemd.user.startServices = "sd-switch";
}
