{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.programs = {
    anyrun.enable = mkEnableOption "Anyrun";
    fuzzel.enable = mkEnableOption "Fuzzel";

    swaylock = {
      enable = mkEnableOption "Swaylock";

      preLockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run before screen locks";
      };

      postLockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run after screen locks";
      };

      postUnlockScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script run after screen unlocks";
      };

      lockScript = mkOption {
        type = types.str;
        readOnly = true;
        description = "Path to lock script";
      };
    };

    hyprlock = {
      enable = mkEnableOption "Hyprlock";
    };
  };
}
