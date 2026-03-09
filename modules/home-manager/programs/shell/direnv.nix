# Setup a new project for devenv with
# `echo "use flake" > .envrc && direnv allow`
# use "use nix" for non-flake projects
{
  lib,
  pkgs,
  args,
}:
let
  direnv-instant = (lib.${lib.ns}.flakePkgs args "direnv-instant").default;
in
{
  enableOpt = false;

  home.packages = [
    (pkgs.runCommand "direnv-instant-wrapped"
      {
        inherit (direnv-instant) meta;
        nativeBuildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${direnv-instant}/bin/direnv-instant $out/bin/direnv-instant \
          --set-default DIRENV_INSTANT_USE_CACHE 1 \
          --set-default DIRENV_INSTANT_MUX_DELAY 4
      ''
    )
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = false; # we use the direnv-instant hook instead
    nix-direnv.enable = true;
  };

  programs.zsh.initContent = ''
    eval "$(direnv-instant hook zsh)"
  '';

  programs.git.settings.core.excludesfile =
    (pkgs.writeText ".gitignore" ''
      .direnv
      .envrc
    '').outPath;
}
