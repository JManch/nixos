{ lib, pkgs, config, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    mkOption
    types
    getExe'
    literalExpression;
  cfg = config.programs.fan2go;
  yamlFormat = pkgs.formats.yaml { };
  configFile = yamlFormat.generate "fan2go.yaml" cfg.settings;
in
{
  options = {
    programs.fan2go = {
      enable = mkEnableOption "fan2go";

      package = mkOption {
        type = types.package;
        default = pkgs.fan2go;
        defaultText = literalExpression "pkgs.fan2go";
        description = "The fan2go package to install";
      };

      settings = mkOption {
        type = yamlFormat.type;
        default = { };
      };

      systemd.enable = mkEnableOption "fan2go systemd integration";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      environment.systemPackages = [ cfg.package ];
      environment.etc."fan2go/fan2go.yaml" = mkIf (cfg.settings != { }) {
        source = configFile;
      };
    }

    (mkIf cfg.systemd.enable {
      systemd.services.fan2go = {
        unitConfig = {
          Description = "Advanced Fan Control Program";
          After = [ "lm-sensors.service" ];
        };

        serviceConfig = {
          ExecStart = "${getExe' cfg.package "fan2go"} -c ${configFile} --no-style";
          LimitNOFILE = 8192;
          Environment = [ "DISPLAY=:0" ];
          Restart = "always";
          RestartSec = 10;
        };

        wantedBy = [ "multi-user.target" ];
      };
    })
  ]);
}
