{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    optionals
    ;
  inherit (lib.${ns}) scanPaths;
  cfg = config.${ns}.shell;
in
{
  imports = scanPaths ./.;

  options.${ns}.shell = {
    enable = mkEnableOption "custom shell environment";
    sillyTools = mkEnableOption "installation of silly shell tools";

    promptColor = mkOption {
      type = types.str;
      default = "green";
      description = "Starship prompt color";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      (with pkgs; [
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
        file
        jaq
      ])
      ++ optionals cfg.sillyTools (
        with pkgs;
        [
          fortune
          cowsay
          lolcat
        ]
      );

    home.sessionVariables.COLORTERM = "truecolor";
  };
}
