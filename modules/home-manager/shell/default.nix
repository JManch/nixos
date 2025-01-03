{
  lib,
  pkgs,
  config,
  selfPkgs,
  ...
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    mkIf
    ;
  cfg = config.${ns}.shell;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.shell = {
    enable = mkEnableOption "custom shell environment";

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
        man-pages
      ])
      ++ [ selfPkgs.microfetch ];

    home.sessionVariables.COLORTERM = "truecolor";
  };
}
