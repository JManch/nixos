{
  lib,
  cfg,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    optionalString
    optional
    ;
  inherit (config.${ns}.desktop.xdg) lowercaseUserDirs;
  impermanence = osConfig.${ns}.system.impermanence or null;
in
{
  opts = with lib; {
    configManager = mkEnableOption "this host as a NixOS config manager";
    backupFiles = mkEnableOption "backing up of ~/files";
  };

  ns = {
    persistence.directories =
      (map (xdgDir: if !lowercaseUserDirs then lib.${ns}.upperFirstChar xdgDir else xdgDir) [
        "downloads"
        "pictures"
        "music"
        "videos"
      ])
      ++ [
        "files"
        "games"
        ".cache/nix"
        ".local/share/systemd" # needed for persistent systemd user timers
      ]
      ++ optional cfg.configManager ".config/nixos";

    backups = {
      nixos = mkIf cfg.configManager {
        backend = "restic";
        paths = [ ".config/nixos" ];
      };

      files = mkIf cfg.backupFiles {
        backend = "restic";
        paths = [ "files" ];
        restore.removeExisting = false;
        backendOptions.exclude =
          let
            absPath = "${optionalString (impermanence.enable or false) "/persist"}${config.home.homeDirectory}";
          in
          [
            "${absPath}/files/repos"
            "${absPath}/files/software"
            "*.qcow2"
          ];
      };
    };
  };

  # Reload systemd services on home-manager restart
  # Add [Unit] X-SwitchMethod=(reload|restart|stop-start|keep-old) to control service behaviour
  systemd.user.startServices = "sd-switch";
}
