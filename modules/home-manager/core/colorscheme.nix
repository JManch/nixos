# Dark Reference
# base00: "#171B24""#F3F4F5"
# base01: "#1F2430""#D9D7CE"
# base02: "#242936""#CCCAC2"
# base03: "#707A8C""#8A9199"
# base04: "#8A9199""#707A8C"
# base05: "#CCCAC2""#242936"
# base06: "#D9D7CE""#1F2430"
# base07: "#F3F4F5""#171B24"
# base08: "#F28779"
# base09: "#FFAD66"
# base0A: "#FFD173"
# base0B: "#D5FF80"
# base0C: "#95E6CB"
# base0D: "#5CCFE6"
# base0E: "#D4BFFF"
# base0F: "#F29E74"

# Light Reference
# base00: "#FAFAFA""#F3F4F5"
# base01: "#F3F4F5""#D9D7CE"
# base02: "#F8F9FA""#CCCAC2"
# base03: "#ABB0B6""#8A9199"
# base04: "#828C99""#707A8C"
# base05: "#5C6773""#242936"
# base06: "#242936""#1F2430"
# base07: "#1A1F29""#171B24"
# base08: "#F07178"
# base09: "#FA8D3E"
# base0A: "#F2AE49"
# base0B: "#86B300"
# base0C: "#4CBF99"
# base0D: "#36A3D9"
# base0E: "#A37ACC"
# base0F: "#E6BA7E"
{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    genAttrs
    attrNames
    ;
  inherit (config.modules.colorScheme) light dark;
in
{
  imports = [ inputs.nix-colors.homeManagerModules.default ];

  options.modules.colorScheme = {
    dark = mkOption {
      type = types.attrs;
      default = inputs.nix-colors.colorSchemes.ayu-mirage;
      description = "Dark color scheme";
    };

    light = mkOption {
      type = types.attrs;
      default = inputs.nix-colors.colorSchemes.ayu-light;
      description = ''
        Light color scheme. Uses first eight from dark color scheme.
      '';
      apply =
        v:
        v
        // {
          palette =
            v.palette
            // (with dark.palette; {
              base00 = base07;
              base01 = base06;
              base02 = base05;
              base03 = base04;
              base04 = base03;
              base05 = base02;
              base06 = base01;
              base07 = base00;
            });
        };
    };

    colorMap = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Attribute set mapping dark theme colors to light theme colors";
      default =
        let
          darkColors = dark.palette;
          lightColors = light.palette;
          baseColors = attrNames darkColors;
        in
        genAttrs baseColors (name: {
          dark = darkColors.${name};
          light = lightColors.${name};
        });
    };
  };

  config = {
    colorScheme = config.modules.colorScheme.dark;
  };
}
