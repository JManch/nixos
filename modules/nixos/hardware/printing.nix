{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkForce;
  cfg = config.modules.hardware.printing;

  dcp9015cdwlpr = pkgs.dcp9020cdwlpr.overrideAttrs (oldAttrs: rec {
    pname = "dcp9015cdw-lpr";
    version = "1.1.3";
    src = pkgs.fetchurl {
      url = "https://download.brother.com/welcome/dlf102113/dcp9015cdwlpr-${version}-0.i386.deb";
      sha256 = "sha256-ySywvrQ51dBMwnKP6IgDW06u560us2K+5ls1gSJB1+c=";
    };
    installPhase = lib.replaceStrings [ "dcp9020cdw" ] [ "dcp9015cdw" ] oldAttrs.installPhase;
  });

  dcp9015cdw-cupswrapper = pkgs.dcp9020cdw-cupswrapper.overrideAttrs (oldAttrs: rec {
    pname = "dcp9015cdw-cupswrapper";
    version = "1.1.4";
    src = pkgs.fetchurl {
      url = "https://download.brother.com/welcome/dlf102114/dcp9015cdwcupswrapper-${version}-0.i386.deb";
      sha256 = "sha256-QUSILXzr2M+huvgXUc1UPpM/C/QoNo5PFUuy3via3EA=";
    };
    installPhase = lib.replaceStrings [ "dcp9020cdw" ] [ "dcp9015cdw" ] oldAttrs.installPhase;
  });
in
mkIf cfg.enable
{
  services.printing = {
    enable = true;
    drivers = [
      dcp9015cdwlpr
      dcp9015cdw-cupswrapper
    ];
  };

  hardware.printers = {
    ensurePrinters = [{
      name = "Brother_DCP-9015CDW";
      deviceUri = "ipp://printer.lan/ipp/print";
      model = "everywhere";
      ppdOptions.PageSize = "A4";
    }];
    ensureDefaultPrinter = "Brother_DCP-9015CDW";
  };

  # Add printer on demand because I don't use it very often. Also works around
  # https://github.com/NixOS/nixpkgs/issues/78535
  systemd.services.ensure-printers.wantedBy = mkForce [ ];
  programs.zsh.shellAliases.enable-printing = "sudo systemctl start ensure-printers.service";
}
