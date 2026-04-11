{
  lib,
  pkgs,
  config,
  categoryCfg,
}:
let
  inherit (config.${lib.ns}.core) color-scheme;
in
{
  enableOpt = false;
  conditions = [ (categoryCfg.locker == "waylock") ];
  categoryConfig = {
    defaultArgs = [
      "-init-color"
      "0x${color-scheme.light.palette."base04"}"
    ];
    package = pkgs.waylock;
  };
}
