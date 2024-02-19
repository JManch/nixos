{ lib, config, ... }:

# I do not like how the config.networking.firewall.allow* options apply
# firewall rules to all interfaces; including those that have per-interface
# rules applied. This means there is no way to create an private interface
# (such as a VPN) that does not have default firewall ports opened. Of course
# I could stop using the default firewall options and instead only use the
# config.networking.firewall.interface.* options - but that would require a
# lot of repition and would not be compatible with 'openFirewall' on modules.

# This module fixes this by overriding the default firewall options so that
# rather than applying default rules to all interfaces, default rules are
# only applied to the configured 'default interfaces'.

let
  inherit (lib) mkIf listToAttrs head;
  cfg = config.modules.system.networking.firewall;
  firewallCfg = config.networking.firewall;
in
# NOTE: My PR https://github.com/NixOS/nixpkgs/pull/288926 can hopefully replace this
mkIf (false)
{
  assertions = [{
    assertion = (cfg.defaultInterfaces != null) && ((head cfg.defaultInterfaces) != [ ]);
    message = "Default firewall interfaces must be defined.";
  }];

  # This ensures that the default firewall rules will not be applied whilst
  # retaining the networking.firewall.allowed* options for our interface
  # definitions
  networking.firewall.allInterfaces = {
    default = {
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = [ ];
    };
  } // firewallCfg.interfaces;

  # Apply the default firewall rules to our configured defaultInterfaces
  networking.firewall.interfaces = listToAttrs (map
    (
      interface: {
        name = interface;
        value = {
          inherit (firewallCfg)
            allowedTCPPorts
            allowedTCPPortRanges
            allowedUDPPorts
            allowedUDPPortRanges;
        };
      }
    )
    cfg.defaultInterfaces);
}
