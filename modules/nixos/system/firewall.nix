# I do not like how the config.networking.firewall.allow* options apply
# firewall rules to all interfaces; including those that have per-interface
# rules applied. This means there is no way to create a private interface (such
# as a VPN) that does not have default firewall ports opened. Of course I could
# stop using the default firewall options and instead only use the
# config.networking.firewall.interface.* options - but that would require a lot
# of repetition and would not be compatible with 'openFirewall' module options
# PR: https://github.com/NixOS/nixpkgs/pull/288926

{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    types
    optionalAttrs
    genAttrs
    hasPrefix
    attrNames
    filter
    ;
in
{
  options.networking.firewall.defaultInterfaces = mkOption {
    type = with types; listOf str;
    default = [ ];
    example = [ "eno1" ];
    description = ''
      If set, networking.firewall.allowed* options are exclusively applied
      to these interfaces.  Otherwise, networking.firewall.allowed* options
      apply to all interfaces.
    '';
  };

  config.networking.firewall.allInterfaces =
    let
      cfg = config.networking.firewall;
      commonOptions = filter (x: hasPrefix "allowed" x) (attrNames config.networking.firewall);

      defaultInterface = optionalAttrs (cfg.defaultInterfaces == [ ]) {
        default = genAttrs commonOptions (option: cfg.${option});
      };

      defaultInterfaces = genAttrs cfg.defaultInterfaces (
        interface:
        genAttrs commonOptions (
          option:
          cfg.${option}
          # Merge will override cfg.interfaces options so concat lists
          ++ cfg.interfaces.${interface}.${option} or [ ]
        )
      );
    in
    defaultInterface // cfg.interfaces // defaultInterfaces;
}
