{
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkEnableOption types mkOption;
in {
  options.font = {
    enable = mkEnableOption "Whether to enable font profiles";
    family = mkOption {
      type = types.str;
      default = null;
      description = "Font family name";
      example = "Fira Code";
    };
    package = mkOption {
      type = types.package;
      default = null;
      description = "Font package";
      example = "pkgs.fira-code";
    };
  };

  config = mkIf config.font.enable {
    fonts.fontconfig.enable = true;
    home.packages = [config.font.package];
  };
}
