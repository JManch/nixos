{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkIf optionals;
  cfg = config.modules.shell;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.shell = {
    enable = mkEnableOption "custom shell environment";
    sillyTools = mkEnableOption "installation of silly shell tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      unzip
      zip
      tree
      wget
      fd
      bat
      tokei
      rename
      nurl # tool for generating nix fetcher calls from urls
    ] ++ optionals cfg.sillyTools [
      fortune
      cowsay
      lolcat
    ];

    home.sessionVariables.COLORTERM = "truecolor";
  };
}
