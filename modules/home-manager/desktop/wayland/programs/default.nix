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
        apply = pkgs.writeShellScript "pre-lock-script";
        description = "Bash script to run before locking";
      };

      postLockScript = mkOption {
        type = types.lines;
        default = "";
        apply = pkgs.writeShellScript "post-lock-script";
        description = "Bash script to run after locking";
      };

      postUnlockScript = mkOption {
        type = types.lines;
        default = "";
        apply = pkgs.writeShellScript "post-unlock-script";
        description = "Bash script to run after locking";
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
            excludeShellChecks = [
              "SC2034"
              "SC1091"
            ];
            text = ''
              immediate=""
              while [ $# -gt 0 ]; do
                case "$1" in
                  --immediate)
                    immediate=true
                    shift
                    ;;
                  *)
                    echo "Unknown option: $1"
                    exit 1
                    ;;
                esac
              done

              # Exit if locker is already running
              pgrep -x ${builtins.baseNameOf (getExe cfg.locking.package)} && exit 1

              # Create a unique lock file so forked processes can track if precisely
              # this instance of the locker is still running
              lockfile="/tmp/lock-$$-$(date +%s)"
              touch "$lockfile"
              trap 'rm -f "$lockfile"' EXIT

              lockArgs=()
              ${optionalString (cfg.locking.immediateFlag != null) # bash
                ''
                  if [ -n "$immediate" ]; then
                    lockArgs+=(${cfg.locking.immediateFlag})
                  fi
                ''
              }

              # source so that scripts inherit lockfile variable
              source ${cfg.locking.preLockScript} || true
              ${escapeShellArg (getExe cfg.locking.package)} "''${lockArgs[@]}" &
              locker_pid=$!
              source ${cfg.locking.postLockScript} || true
              wait $locker_pid
              source ${cfg.locking.postUnlockScript} || true
            '';
          }
        );
      };
    };
  };
}
