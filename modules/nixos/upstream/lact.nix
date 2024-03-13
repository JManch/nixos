{ lib, pkgs, config, ... }:
let
  inherit (lib)
    mkIf
    getExe
    mkEnableOption
    mkOption
    mkPackageOption;
  cfg = config.services.lact;
  yamlFormat = pkgs.formats.yaml { };
  configFile = yamlFormat.generate "config.yaml" cfg.settings;
in
{
  options = {
    services.lact = {
      enable = mkEnableOption "Lact";
      package = mkPackageOption pkgs "lact" { };

      settings = mkOption {
        type = yamlFormat.type;
        default = { };
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."lact/config.yaml" = mkIf (cfg.settings != { }) {
      source = configFile;
    };

    systemd.services.lact = {
      unitConfig = {
        Description = "AMDGPU Control Daemon";
        After = [ "multi-user.service" ];
      };

      serviceConfig = {
        ExecStart = "${getExe cfg.package} daemon";
        Restart = "always";
        RestartSec = "3s";
      };

      wantedBy = [ "multi-user.target" ];
    };
  };
}
