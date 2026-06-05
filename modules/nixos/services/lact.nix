{
  lib,
  cfg,
  username,
  adminUsername,
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    optional
    ;
in
{
  opts = {
    acknowledgeUserIssue = mkEnableOption "acknowledge user issue" // {
      default = username == adminUsername;
    };

    config = mkOption {
      type = with types; nullOr lines;
      description = "Lact yaml config";
    };
  };

  warnings = optional (!cfg.acknowledgeUserIssue) ''
    Lact cannot connect to the daemon if the user running the application is
    not a member of the wheel group. Fix the issue by setting:
      `admin_user: ${username}`
  '';

  services.lact.enable = true;
  # Not using `lact.settings` because the keys for fan curve have to be
  # integers
  # https://github.com/NixOS/nixpkgs/pull/427876#issuecomment-3694036066
  environment.etc."lact/config.yaml" = lib.mkIf (cfg.config != null) {
    text = cfg.config;
  };
}
