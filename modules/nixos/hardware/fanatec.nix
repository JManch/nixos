{ lib, config, inputs, ... }:
let
  cfg = config.modules.hardware.fanatec;
in
lib.mkIf cfg.enable
{
  boot = {
    kernelModules = [ "hid-fanatec" ];
    extraModulePackages = [
      (config.boot.kernelPackages.callPackage "${inputs.nix-resources}/pkgs/hid-fanatecff.nix" { })
    ];
  };
}
