{ lib, pkgs, config, ... } @ args:
let
  inherit (lib) mkIf getExe utils optional;
  cfg = config.modules.programs.gaming.mint;
  mint = ((utils.flakePkgs args "mint").default).overrideAttrs (oldAttrs: {
    # Patch removes the [MODDED] prefix from lobby names. I only use verified
    # and local mods.
    patches = (oldAttrs.patches or [ ]) ++ [ ../../../../patches/mint.patch ];
  });
in
mkIf cfg.enable
{
  home.packages = optional cfg.enable mint;

  xdg.desktopEntries."mint" = {
    name = "mint";
    genericName = "Mod Loader";
    exec = "${getExe mint}";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
  };

  backups.mint.paths = [ ".config/mint" ];

  persistence.directories = [
    ".config/mint"
  ];
}
