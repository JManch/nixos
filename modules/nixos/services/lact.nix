{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe;
  inherit (config.device) gpu;
  cfg = config.modules.services.lact;
in
mkIf (cfg.enable && (gpu.type == "amd"))
{
  environment.systemPackages = [ pkgs.lact ];

  system.services.lact = {
    unitConfig = {
      Description = "AMDGPU Control Daemon";
      After = [ "multi-user.target" ];
    };

    serviceConfig = {
      ExecStart = "${getExe pkgs.lact} daemon";
    };

    wantedBy = [ "multi-user.target" ];
  };
}
