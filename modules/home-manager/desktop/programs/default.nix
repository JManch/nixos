{ lib, pkgs, ... }:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    ;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.desktop.programs = {
    fuzzel.enable = mkEnableOption "Fuzzel";
    swaylock.enable = mkEnableOption "Swaylock";
    hyprlock.enable = mkEnableOption "Hyprlock";

    locker = {
      package = mkOption {
        type = with types; nullOr package;
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
        description = "Script that locks the screen";
      };
    };
  };
}
