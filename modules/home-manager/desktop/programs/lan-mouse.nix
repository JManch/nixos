{
  lib,
  cfg,
  pkgs,
  args,
  config,
  inputs,
  hostname,
}:
let
  inherit (lib)
    ns
    mapAttrs'
    filterAttrs
    genAttrs
    mapAttrsToList
    mkOption
    types
    nameValuePair
    ;
  inherit (lib.${ns})
    hostIps
    flakePkgs
    mkHyprlandCenterFloatRule
    ;
  inherit (config.age.secrets) lanMouseCert;
  lan-mouse = (flakePkgs args "lan-mouse").default;
  otherFingerprints = filterAttrs (
    h: _: h != hostname
  ) inputs.nix-resources.secrets.lanMouseAuthorizedFingerprints;
in
{
  opts = {
    port = mkOption {
      type = types.port;
      default = 4242;
    };

    interfaces = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Interfaces to expose the service on";
    };
  };

  home.packages = [
    (pkgs.symlinkJoin {
      name = "lan-mouse-wrapped";
      paths = [ lan-mouse ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/lan-mouse --add-flags '--cert-path ${lanMouseCert.path}'
      '';
    })
  ];

  xdg.configFile."lan-mouse/config.toml".source = (pkgs.formats.toml { }).generate "config.toml" {
    port = cfg.port;

    authorized_fingerprints = mapAttrs' (h: fingerprint: nameValuePair fingerprint h) otherFingerprints;

    clients = mapAttrsToList (h: _: {
      hostname = h;
      ips = hostIps h;
    }) otherFingerprints;
  };

  ns.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedUDPPorts = [ cfg.port ];
  });

  ns.desktop.hyprland.windowRules."lan-mouse" =
    mkHyprlandCenterFloatRule "de\\.feschber\\.LanMouse" 25
      60;
}
