{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf getExe getExe';
  inherit (config.device) gpu;
  cfg = config.modules.services.corectrl;
in
mkIf (cfg.enable && (gpu.type == "amd"))
{
  users.users.${username}.extraGroups = [ "corectrl" ];

  programs.corectrl = {
    enable = true;

    # Latest version has 7900xt fan curve support
    package = pkgs.corectrl.overrideAttrs (prev: {
      version = "2024-02-27";
      src = pkgs.fetchFromGitLab {
        owner = "corectrl";
        repo = "corectrl";
        rev = "f8bf0e920df2358ee9e98d61bd74b2e357b04a94";
        sha256 = "sha256-v2Ugy4ZaZGBgjU9lJlbQ2qv/3qa6DQYKw5XvRx55GqY=";
      };
      buildInputs = with pkgs; prev.buildInputs ++ [ spdlog pugixml ];
    });

    # WARN: Disable this if you experience flickering or general instability
    # https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
    gpuOverclock.enable = true;
    gpuOverclock.ppfeaturemask = "0xffffffff";
  };

  systemd.user.services.corectrl = {
    unitConfig = {
      Description = "Corectrl system hardware tuner";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session-pre.target" ];
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = getExe' config.programs.corectrl.package "corectrl";
      ExecStop = "-${getExe pkgs.killall} corectrl";
      # Closing the window fully quits corectrl so we have to force restart
      Restart = "on-success";
      RestartSec = 3;
    };

    wantedBy = [ "graphical-session.target" ];
  };

  persistenceHome.directories = [ ".config/corectrl" ];
}
