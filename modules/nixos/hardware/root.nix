{ lib, hostname }:
let
  inherit (lib)
    mkOption
    types
    hasPrefix
    mkEnableOption
    literalExpression
    ;
in
{
  exclude = [
    "raspberry-pi.nix"
    "nix-on-droid.nix"
  ];

  # raspberry-pi.nix is only imported when the host is a raspberry-pi so we
  # have to define options here
  opts.raspberry-pi = {
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
