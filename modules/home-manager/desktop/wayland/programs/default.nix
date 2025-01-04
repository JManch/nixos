{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    getExe
    mkEnableOption
    mkOption
    types
    escapeShellArg
    optionalString
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

      immediateFlag = mkOption {
        type = with types; nullOr str;
        default = null;
        description = ''
          Flag for immediate locking (meaning skipping the grace period). Leave
          null if unsupported.
        '';
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
              coreutils
              procps
            ];
            text = ''
              # Exit if locking is currently running
              pgrep -x ${builtins.baseNameOf (getExe cfg.locking.package)} && exit 1

              # Create a unique lock file so forked processes can track if precisely
              # this instance of the locker is still running
              lockfile="/tmp/lock-$$-$(date +%s)"
              touch "$lockfile"
              trap 'rm -f "$lockfile"' EXIT

              lockArgs=()
              ${optionalString (cfg.locking.immediateFlag != null) # bash
                ''
                  if [ -e /tmp/lock-immediately ]; then
                    lockArgs+=(${cfg.locking.immediateFlag})
                    rm -f /tmp/lock-immediately || true
                  fi
                ''
              }

              ${cfg.locking.preLockScript}
              ${escapeShellArg (getExe cfg.locking.package)} "''${lockArgs[@]}" &
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
