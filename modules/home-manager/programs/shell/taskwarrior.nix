{
  lib,
  cfg,
  pkgs,
  inputs,
}:
let
  inherit (lib)
    singleton
    mkEnableOption
    mkOption
    types
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
in
{
  opts = {
    primaryClient = mkEnableOption ''
      Whether this is the primary Taskwarrior client for this user
    '';

    userUuid = mkOption {
      type = types.str;
      default = "565b3910-9d0b-4c2c-9bfc-b3195aac9d8f";
      description = ''
        Randomly generated UUID that identifies a user on the Taskchampion
        sync server
      '';
    };
  };

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
    colorTheme = "dark-256";
    extraConfig = ''
      news.version=3.1.0
      include $XDG_RUNTIME_DIR/agenix/taskwarriorSyncEncryption
      sync.server.url=https://tasks.${fqDomain}
      sync.server.client_id=${cfg.userUuid}

      # https://github.com/GothenburgBitFactory/taskwarrior/blob/2e3badbf991e726ba0f0c4b5bb6b243ea2dcdfc3/doc/man/taskrc.5.in#L489
      recurrence=${if cfg.primaryClient then "1" else "0"}
    '';
  };

  home.packages = [ pkgs.taskwarrior-tui ];

  darkman.switchApps.taskwarrior = {
    paths = [ ".config/task/home-manager-taskrc" ];
    extraReplacements = singleton {
      dark = "dark-256";
      light = "light-256";
    };
  };

  nsConfig.persistence.directories = [
    ".local/share/task"
    ".local/share/taskwarrior-tui"
  ];
}
