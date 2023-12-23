{lib, ...}: let
  inherit (lib) types mkOption;
in {
  options.system = {
    hostname = mkOption {
      type = types.str;
      default = null;
      description = "System hostname";
    };
  };
}
