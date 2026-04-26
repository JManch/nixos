{ lib, cfg }:
{
  opts.config =
    with lib;
    mkOption {
      type = types.lines;
      description = "Lact yaml config";
    };

  services.lact.enable = true;
  # Not using `lact.settings` because the keys for fan curve have to be
  # integers
  # https://github.com/NixOS/nixpkgs/pull/427876#issuecomment-3694036066
  environment.etc."lact/config.yaml".text = cfg.config;
}
