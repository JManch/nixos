{
  lib,
  config,
  osConfig,
  osConfig',
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    optionalString
    types
    mkEnableOption
    optional
    mkOption
    ;
  inherit (lib.${ns}) scanPaths upperFirstChar;
  inherit (config.${ns}.desktop.xdg) lowercaseUserDirs;
  impermanence = osConfig'.${ns}.system.impermanence or null;
  cfg = config.${ns}.core;
in
{
  imports = scanPaths ./.;

  options.${ns}.core = {
    configManager = mkEnableOption "this host as a NixOS config manager";
    backupFiles = mkEnableOption "backing up of ~/files";

    standalone = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether this home-manager config is deployed alongside a NixOS config
        or is standalone. Standalone configurations can be deployed on
        non-NixOS hosts.
      '';
    };
  };

  config = {
    _module.args.osConfig' = if cfg.standalone then null else osConfig;

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
        ".local/share/systemd" # needed for persistent user timers to work properly
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
