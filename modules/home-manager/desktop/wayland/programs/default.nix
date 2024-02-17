{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.programs = {
    anyrun.enable = mkEnableOption "anyrun";

    swaylock = {
      enable = mkEnableOption "swaylock";

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
    };
  };
}
