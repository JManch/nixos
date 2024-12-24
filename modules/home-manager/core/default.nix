{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    optionalString
    mkEnableOption
    optional
    ;
  inherit (lib.${ns}) scanPaths upperFirstChar;
  inherit (config.${ns}.desktop.xdg) lowercaseUserDirs;
  impermanence = osConfig.${ns}.system.impermanence or null;
  cfg = config.${ns}.core;
in
{
  imports = scanPaths ./.;

  options.${ns}.core = {
    configManager = mkEnableOption "this host as a NixOS config manager";
    backupFiles = mkEnableOption "backing up of ~/files";
  };

  config = {
    persistence.directories =
      (map (xdgDir: if !lowercaseUserDirs then upperFirstChar xdgDir else xdgDir) [
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
      nixos = mkIf cfg.configManager { paths = [ ".config/nixos" ]; };

      files = mkIf cfg.backupFiles {
        paths = [ "files" ];
        restore.removeExisting = false;
        exclude =
          let
            absPath = "${optionalString (impermanence.enable or false) "/persist"}${config.home.homeDirectory}";
          in
          [
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
