{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    getExe
    mkEnableOption
    mkOption
    types
    optionalString
    escapeShellArg
    ;
  cfg = config.${ns}.desktop.programs;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.desktop.programs = {
    fuzzel.enable = mkEnableOption "Fuzzel";
    swww.enable = mkEnableOption "Swww";
    swaylock.enable = mkEnableOption "Swaylock";
    hyprlock.enable = mkEnableOption "Hyprlock";

    locking = {
      package = mkOption {
        type = types.package;
        default = null;
        description = "The package to use for locking";
      };

      preLockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run before locking";
      };

      postLockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run after locking";
      };

      postUnlockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run after locking";
      };

      lockScript = mkOption {
        type = types.str;
        readOnly = true;
        default = getExe (
          pkgs.writeShellApplication {
            name = "lock-script";

            runtimeInputs = with pkgs; [
              wireplumber
              gnugrep
              procps
              coreutils
            ];

            text = ''
              # Exit if locking is currently running
              pgrep -x ${builtins.baseNameOf (getExe cfg.locking.package)} && exit 1

              # Create a unique lock file so forked processes can track if precisely
              # this instance of the locker is still running
              lockfile="/tmp/lock-$$-$(date +%s)"
              touch "$lockfile"
              trap 'rm -f "$lockfile"' EXIT

              ${cfg.locking.preLockScript}
              ${escapeShellArg (getExe cfg.locking.package)} &
              LOCKER_PID=$!
              ${cfg.locking.postLockScript}
              wait $LOCKER_PID
              ${cfg.locking.postUnlockScript}
            '';
          }
        );
      };
    };
  };
}
