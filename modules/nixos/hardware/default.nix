{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  imports = [
    ./graphics
    ./filesystem.nix
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
        type = types.nullOr types.str;
        description = ''
          Maximum size of the volatile root tmpfs partition. Default is to not
          specific size which will allocated 50% of system memory to the tmpfs.
          Memory is dynamically allocated so will not effect system memory
          unless necessary.
        '';
        example = "8G";
        default = null;
      };
    };

    vr = mkEnableOption "virtual reality";
  };
}
