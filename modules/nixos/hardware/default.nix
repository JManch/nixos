{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  imports = [
    ./graphics
    ./filesystem.nix
    # ./bluetooth.nix TODO:
  ];

  options.modules.hardware = {
    fileSystem = {
      zpoolName = mkOption {
        type = types.str;
        description = "Name of the zpool to mount";
        default = "zpool";
      };
      bootLabel = mkOption {
        type = types.str;
        description = "Label of the boot partition";
        default = "boot";
      };
      trim = mkEnableOption "ZFS automatic trimming";
      rootTmpfsSize = mkOption {
        type = types.str;
        description = "Size of the volatile root tmpfs partition";
        example = "4G";
        default = "1G";
      };
    };
  };
}
