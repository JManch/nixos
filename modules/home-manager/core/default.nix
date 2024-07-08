{ lib, config, osConfig, ... }:
let
  inherit (lib) mkIf utils optionalString mkEnableOption optional;
  inherit (osConfig.modules.system) impermanence;
  cfg = config.modules.core;
in
{
  imports = utils.scanPaths ./.;

  options.modules.core = {
    configManager = mkEnableOption "this host as a NixOS config manager";
    backupFiles = mkEnableOption "backing up of ~/files";
  };

  config = {
    home.stateVersion = "23.05";

    persistence.directories = [
      "downloads"
      "pictures"
      "music"
      "videos"
      "files"
      ".cache/nix"
      ".local/share/systemd" # needed for persistent user timers to work properly
    ] ++ optional cfg.configManager ".config/nixos";

    backups = {
      nixos = mkIf cfg.configManager {
        paths = [ ".config/nixos" ];
      };

      files = mkIf cfg.backupFiles {
        paths = [ "files" ];
        restore.removeExisting = false;
        exclude =
          let
            absPath = "${optionalString impermanence.enable "/persist"}${config.home.homeDirectory}";
          in
          [
            "${absPath}/files/games"
            "${absPath}/files/repos"
            "${absPath}/files/software"
          ];
      };
    };

    # Reload systemd services on home-manager restart
    # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
    systemd.user.startServices = "sd-switch";
  };
}
