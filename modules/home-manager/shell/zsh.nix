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
mkIf cfg.enable {
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
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
      rebuild-switch = "sudo nixos-rebuild switch --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-test = "sudo nixos-rebuild test --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-boot = "sudo nixos-rebuild boot --flake /home/${username}/.config/nixos#${hostname}";
      # cd here because I once had a bad experience where I accidentally built
      # in /nix/store and it irrepairably corrupted the store
      rebuild-build = "cd && nixos-rebuild build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-dry-build = "nixos-rebuild dry-build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-dry-activate = "sudo nixos-rebuild dry-activate --flake /home/${username}/.config/nixos#${hostname}";
      inspect-nix-config = "nix --extra-experimental-features repl-flake repl '/home/${username}/.config/nixos#nixosConfigurations.${hostname}'";
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
