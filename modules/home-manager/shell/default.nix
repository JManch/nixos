{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf optionals;
  cfg = config.modules.shell;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.shell = {
    enable = mkEnableOption "custom shell environment";
    sillyTools = mkEnableOption "installation of silly shell tools";

    promptColor = mkOption {
      type = types.str;
      default = "green";
      description = "Starship prompt color";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      unzip
      zip
      tree
      wget
      fd
      ripgrep
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
