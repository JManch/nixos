# Setup a new project for devenv with
# `echo "use flake" > .envrc && direnv allow`
# use "use nix" for non-flake projects
{ pkgs }:
{
  enableOpt = false;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false; # we define the hook ourselves
  };

  programs.zsh.initContent = # bash
    ''
      # Suppress the env vars https://ianthehenry.com/posts/how-to-learn-nix/nix-direnv/
      export DIRENV_LOG_FORMAT="$(printf "\033[2mdirenv: %%s\033[0m")"
      eval "$(direnv hook zsh)"
      _direnv_hook() {
        eval "$(direnv export zsh 2> >(egrep -v -e '^....direnv: export' >&2))"
      };
    '';

  programs.git.settings.core.excludesfile =
    (pkgs.writeText ".gitignore" ''
      .direnv
      .envrc
    '').outPath;

  ns.persistence.directories = [ ".local/share/direnv" ];
}
