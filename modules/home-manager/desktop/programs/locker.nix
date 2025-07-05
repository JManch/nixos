{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    getExe
    optionalString
    escapeShellArg
    concatMapStringsSep
    mkOption
    types
    ;
  # https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226
  lockerName = builtins.unsafeDiscardStringContext (builtins.baseNameOf (getExe cfg.package));
in
{
  enableOpt = false;
  conditions = [ (cfg.package != null) ];

  asserts = [
    osConfig.programs.uwsm.enable
    "Locker requires UWSM to be enabled"
  ];

  opts = {
    package = mkOption {
      type = with types; nullOr package;
      default = null;
      description = "The package to use for locking";
    };

    defaultArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "List of default args passed to lock command";
    };

    immediateArgs = mkOption {
      type = with types; nullOr (listOf str);
      default = null;
      description = ''
        Args for immediate locking (meaning skipping the grace period). Leave
        null if unsupported.
      '';
    };

    unlockCmd = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        Command that unlocks the locker. Used to unlock when resuming from
        hibernation on hosts that use passphrase-protected full disk
        encryption. Must work when run as root.
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
      description = "Script that locks the screen";
    };
  };

  ns.desktop = {
    programs.locker.lockScript =
      (pkgs.writeShellScript "lock-script" # bash
        ''
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
          systemctl --quiet --user is-active app-*-${builtins.baseNameOf (getExe cfg.package)}@*.service && exit 1

          lockArgs=(${concatMapStringsSep " " (s: "\"${s}\"") cfg.defaultArgs})

          ${optionalString (cfg.immediateArgs != null) ''
            if [ -n "$immediate" ]; then
              lockArgs+=(${concatMapStringsSep " " (s: "\"${s}\"") cfg.immediateArgs})
            fi
          ''}

          exec ${getExe pkgs.app2unit} -- ${escapeShellArg (getExe cfg.package)} "''${lockArgs[@]}"
        ''
      ).outPath;

    uwsm = {
      serviceApps = [ lockerName ];
      appUnitOverrides."${lockerName}@.service" = ''
        [Service]
        # Exit type main is required so that the service stops even if there
        # are background processes running from the pre/post lock scripts
        ExitType=main
        # KillMode control-group ensures that any background processes started
        # from the preLock or postLock scripts get killed. postUnlock script
        # will be given TimeoutStopSec (90 secs default) to finish.
        KillMode=control-group
        ExecStartPre=-${cfg.preLockScript}
        ExecStartPost=-${cfg.postLockScript}
        ExecStopPost=-${cfg.postUnlockScript}
      '';
    };
  };

  systemd.user.services.inhibit-lock = {
    Unit.Description = "Inhibit Lock";
    Service.ExecStart = "systemd-inhibit --who='Inhibit Lock' --what=idle --why='User request' sleep infinity";
  };

  wayland.windowManager.hyprland.settings.bind =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;
      notifySend = getExe pkgs.libnotify;
      toggleLockInhibit = pkgs.writeShellScript "toggle-lock-inhibit" ''
        systemctl is-active --quiet --user inhibit-lock && {
          systemctl stop --quiet --user inhibit-lock
          ${notifySend} -e --urgency=low -t 2000 'Locker' 'Locking uninhibited'
        } || {
          systemctl start --quiet --user inhibit-lock
          ${notifySend} -e --urgency=low -t 2000 'Locker' 'Locking inhibited'
        }
      '';
    in
    [
      "${modKey}, U, exec, ${toggleLockInhibit}"
      "${modKey}, Escape, exec, ${cfg.lockScript} --immediate"
    ];
}
