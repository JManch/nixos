{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    optionalString
    escapeShellArg
    ;
  cfg = config.${ns}.desktop.programs.locker;
  # https://discourse.nixos.org/t/not-allowed-to-refer-to-a-store-path-error/5226
  lockerName = builtins.unsafeDiscardStringContext (builtins.baseNameOf (getExe cfg.package));
in
mkIf (cfg.package != null) {
  assertions = lib.${ns}.asserts [
    osConfig.programs.uwsm.enable
    "Locker requires UWSM to be enabled"
  ];

  ${ns}.desktop = {
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

          ${optionalString (cfg.immediateFlag != null) ''
            if [ -n "$immediate" ]; then
              lockArgs+=(${cfg.immediateFlag})
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
        ExecStartPre=-${cfg.preLockScript}
        ExecStartPost=-${cfg.postLockScript}
        ExecStopPost=-${cfg.postUnlockScript}
      '';
    };
  };
}
