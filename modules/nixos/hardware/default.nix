{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.hardware = {
    vr.enable = mkEnableOption "virtual reality";
    secureBoot.enable = mkEnableOption "secure boot";
    fanatec.enable = mkEnableOption "support for Fanatec hardware";

    fileSystem = {
      trim = mkEnableOption "ZFS automatic trimming";
      unstableZfs = mkEnableOption "unstable ZFS";
      extendedLoaderTimeout = mkEnableOption ''
        an extended loader timeout of 30 seconds. Useful for switching to old
        generations on headless machines.
      '';

      forceImportRoot = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Should set to false after initial setup. May cause ZFS import to
          break so be prepared to set `zfs_force=1` kernel param in boot menu.
        '';
      };
    };
  };
}
