{ lib, pkgs, config, ... } @ args:
let
  inherit (lib) utils mkEnableOption mkOption types mkIf optionals;
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
      (utils.flakePkgs args "yaml2nix").default
    ] ++ optionals cfg.sillyTools [
      fortune
      cowsay
      lolcat
    ];

    home.sessionVariables.COLORTERM = "truecolor";
  };
}
