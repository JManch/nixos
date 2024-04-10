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

      zpoolName = mkOption {
        type = types.str;
        default = "zpool";
        description = "Name of the zpool to mount";
      };

      forceImportRoot = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Should set to false after initial setup. May cause ZFS import to
          break so be prepared to set `zfs_force=1` kernel param in boot menu.
        '';
      };

      bootLabel = mkOption {
        type = types.str;
        default = "boot";
        description = "Label of the boot partition";
      };

      rootTmpfsSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "8G";
        description = ''
          Maximum size of the volatile root tmpfs partition. By default, will
          allocated 50% of system memory to the tmpfs. Memory is dynamically
          allocated so will not use system memory unless necessary.
        '';
      };
    };
  };
}
