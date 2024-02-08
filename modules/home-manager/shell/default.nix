{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption;
  cfg = config.modules.shell;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.shell = {
    enable = mkEnableOption "enable custom shell";
    sillyTools = mkEnableOption "install silly command-line tools";
  };

  config = lib.mkIf cfg.enable {
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
    ] ++ lib.lists.optionals cfg.sillyTools [
      fortune
      cowsay
      lolcat
    ];

    home.sessionVariables = {
      COLORTERM = "truecolor";
    };
  };
}
