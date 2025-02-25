{ lib, hostname }:
let
  inherit (lib)
    mkOption
    types
    mkEnableOption
    hasPrefix
    literalExpression
    ;
in
{
  exclude = [
    "raspberry-pi.nix"
    "nix-on-droid.nix"
  ];

  opts.raspberryPi = {
    enable = mkOption {
      type = types.bool;
      readOnly = true;
      default = hasPrefix "pi" hostname;
      description = "Whether this host is a raspberry pi";
    };

    uboot = {
      enable = removeAttrs (mkEnableOption "uboot bootloader (disable on newer pis)") [ "default" ];

      package = mkOption {
        type = types.package;
        example = literalExpression "pkgs.ubootRaspberryPi3_64bit";
        description = ''
          The uboot package to use. The overlay raspberry-pi-nix uses breaks
          things so we replace it.
        '';
      };
    };
  };
}
