{ lib, config, ... }:

{
  options.font = {
    enable = lib.mkEnableOption "Whether to enable font profiles";
    family = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Font family name";
      example = "Fira Code";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "Font package";
      example = "pkgs.fira-code";
    };
  };

  config = lib.mkIf config.font.enable {
    fonts.fontconfig.enable = true;
    home.packages = [ config.font.package ];
  };
}
