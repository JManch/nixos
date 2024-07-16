{
  lib,
  pkgs,
  config,
  ...
}@args:
let
  inherit (lib)
    utils
    mkEnableOption
    mkOption
    types
    mkIf
    optionals
    ;
  cfg = config.modules.shell;

  tomato-c = pkgs.tomato-c.overrideAttrs (_: {
    version = "2024-06-11";
    src = pkgs.fetchFromGitHub {
      owner = "gabrielzschmitz";
      repo = "Tomato.C";
      rev = "b3b85764362a7c120f3312f5b618102a4eac9f01";
      hash = "sha256-7i+vn1dAK+bAGpBlKTnSBUpyJyRiPc7AiUF/tz+RyTI=";
    };
    patches = [ ];
    postPatch = ''
      substituteInPlace notify.c \
        --replace-fail "/usr/local" "${placeholder "out"}"
      substituteInPlace util.c \
        --replace-fail "/usr/local" "${placeholder "out"}"
      substituteInPlace tomato.desktop \
        --replace-fail "/usr/local" "${placeholder "out"}"
      substituteInPlace Makefile \
        --replace-fail "sudo" ""
    '';
  });
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
      ])
      ++ [
        (utils.flakePkgs args "yaml2nix").default
        tomato-c
      ]
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
