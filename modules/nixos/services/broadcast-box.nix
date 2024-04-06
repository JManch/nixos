{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mkForce optional;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) wireguard;
  cfg = config.modules.services.broadcast-box;

  # Overriding buildGoModule packages is not elegant...
  broadcast-box =
    let
      version = "2024-03-20";
      src = pkgs.fetchFromGitHub {
        repo = "broadcast-box";
        owner = "Glimesh";
        rev = "b37dd4ce79741849e1601812ac7f70fa6a2e0f02";
        sha256 = "sha256-kDpDELp7yjDtCwZYd1rg/JsemE9zTxQh1Bucz9pgl3o=";
      };
    in
    (pkgs.broadcast-box.overrideAttrs (oldAttrs: {
      frontend = pkgs.buildNpmPackage {
        version = oldAttrs.version;
        pname = "${oldAttrs.pname}-web";
        src = "${src}/web";
        npmDepsHash = "sha256-/rlyfQMolsfgtk9wxfi5DUy/ZxCny5ahKGu9aoJEzWw=";
        preBuild = ''
          # The REACT_APP_API_PATH environment variable is needed
          cp "${src}/.env.production" ../
        '';
        installPhase = ''
          mkdir -p $out
          cp -r build $out
        '';
      };
    })).override {
      buildGoModule = args: pkgs.buildGoModule (args // {
        inherit src version;
        # Because the package uses proxyVendor it seems that vendorHashe breaks
        # everytime go updates...
        vendorHash = "sha256-in31kbbZAexbHuqeZ8BpPw3jCTeJsEHM2IGajXlyIDg=";
      });
    };
in
mkIf cfg.enable
{
  services.broadcast-box = {
    enable = true;
    package = broadcast-box;
    http.port = cfg.port;
    udpMux.port = cfg.udpMuxPort;
    # This breaks local streaming without hairpin NAT so hairpin NAT is needed
    # for streaming from local network when proxying
    nat.autoConfigure = cfg.proxy;
    statusAPI = !cfg.proxy;
  };

  systemd.services.broadcast-box.wantedBy = mkForce (
    optional cfg.autoStart "multi-user.target"
  );

  # When not proxying only expose over wg interface
  networking.firewall.interfaces.wg-friends = mkIf (wireguard.friends.enable && !cfg.proxy) {
    allowedTCPPorts = [ cfg.port ];
    allowedUDPPorts = [ cfg.udpMuxPort ];
  };

  modules.system.networking.publicPorts = [ cfg.udpMuxPort ];
  networking.firewall.allowedUDPPorts = mkIf cfg.proxy [ cfg.udpMuxPort ];

  services.caddy.virtualHosts."stream.${fqDomain}".extraConfig = mkIf cfg.proxy ''
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';
}
