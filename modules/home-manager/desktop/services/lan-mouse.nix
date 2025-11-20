{
  lib,
  cfg,
  pkgs,
  args,
  config,
  inputs,
  hostname,
  osConfig,
}:
let
  inherit (lib)
    ns
    getExe
    mkIf
    mapAttrs'
    filterAttrs
    genAttrs
    mapAttrsToList
    mkOption
    types
    nameValuePair
    ;
  inherit (lib.${ns}) sliceSuffix hostIps flakePkgs;
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
        wrapProgram $out/bin/lan-mouse --run '
          systemctl start --user lan-mouse.service
        '
      '';
    })
  ];

  systemd.user.services."lan-mouse" = {
    Unit = {
      Description = "Lan Mouse";
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecStart = "${getExe lan-mouse} --cert-path ${lanMouseCert.path} daemon";
    };
  };

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
}
