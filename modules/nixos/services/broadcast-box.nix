{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkForce optional;
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
        vendorHash = "sha256-vDtuzs4LS2PPRDzhRE/p8wG/04bVfviYOkSuHVypb8g=";
      });
    };
in
mkIf cfg.enable
{
  services.broadcast-box = {
    enable = true;
    package = broadcast-box;
    http.port = 8080;
    udpMux.port = 3000;
    openFirewall = true;
    # This breaks local streaming because I do not use hairpin NAT
    nat.autoConfigure = true;
    statusAPI = false;
  };

  systemd.services.broadcast-box.wantedBy = mkForce (
    optional cfg.autoStart [ "multi-user.target" ]
  );

  networking.firewall.interfaces.wg-discord = {
    allowedTCPPorts = [ 8080 ];
    allowedUDPPorts = [ 3000 ];
  };
}
