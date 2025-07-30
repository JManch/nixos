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
    toSentenceCase
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
      (map (xdgDir: if !lowercaseUserDirs then toSentenceCase xdgDir else xdgDir) [
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

  # sd-switch broke after https://github.com/nix-community/home-manager/commit/de448dcb577570f2a11f243299b6536537e05bbe
  # https://github.com/nix-community/home-manager/issues/7583
  # I'd rather restart services manually anyway so disabling
  # WARN: If I ever re-enable this check the commit history cause I removed all
  # the X-SwitchMethod override
  systemd.user.startServices = false;
}
