{ pkgs, categoryCfg }:
{
  enableOpt = false;
  conditions = [ (categoryCfg.locker == "waylock") ];
  categoryConfig.package = pkgs.waylock;
}
