{ lib
, pkgs
, config
, username
, hostname
, ...
}:
let
  inherit (lib) mkIf getExe';
  cfg = config.modules.shell;
in
mkIf cfg.enable
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    dotDir = ".config/zsh";

    syntaxHighlighting = {
      enable = true;
      styles = {
        path = "none";
        path_prefix = "none";
        unknown-token = "fg=red";
        precommand = "fg=green";
      };
    };

    history = {
      path = "${config.xdg.stateHome}/zsh/zsh_history";
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
    };

    shellAliases = {
      cat = "bat -pp --theme=base16";
      reload = "exec zsh";
      inspect-nix-config = "nix --extra-experimental-features repl-flake repl /home/${username}/.config/nixos#nixosConfigurations.${hostname}";
    };

    initExtra =
      let
        reboot = getExe' pkgs.systemd "reboot";
      in
        /*bash*/ ''

        setopt interactivecomments

        reboot() {
          read -q "REPLY?Are you sure you want to reboot? (y/N)"
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${reboot}
          fi
        }

        edit-home-file() {
          if [ -z "$1" ] || [ ! -e "$1" ]; then
            echo "Usage: edit-home-file <file_path>"
            return 1
          fi

          file_path="$1"
          dir_path=$(dirname "$file_path")
          file_name=$(basename -- "$file_path")

          copy_path="$dir_path/''${file_name%.*}.copy.''${file_name##*.}"
          cat "$file_path" > "$copy_path" && rm "$file_path" && mv "$copy_path" "$file_path"
          $EDITOR "$file_path"
        }

      '';
  };

  persistence.directories = [
    ".config/zsh" # for zcompdump
    ".local/state/zsh"
    ".cache/zsh"
  ];
}
