{ lib, pkgs, config, ... }:
let
  cfg = config.modules.hardware.secureBoot;
in
lib.mkIf cfg.enable
{
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  environment.persistence."/persist".directories = [
    "/etc/secureboot"
  ];
}
