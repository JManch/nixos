{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    mkEnableOption
    mkOption
    types
    mkPackageOption
    ;
  cfg = config.services.lact;
in
{
  options = {
    services.lact = {
      enable = mkEnableOption "Lact";
      package = mkPackageOption pkgs "lact" { };

      settings = mkOption {
        type = types.str;
        default = "";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."lact/config.yaml" = mkIf (cfg.settings != "") { text = cfg.settings; };

    systemd.services.lact = {
      unitConfig = {
        Description = "AMDGPU Control Daemon";
        After = [ "multi-user.service" ];
      };

      serviceConfig = {
        ExecStart = "${getExe cfg.package} daemon";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
