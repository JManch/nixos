{ lib
, pkgs
, config
, username
, hostname
, ...
}:
let
  cfg = config.modules.shell;
in
lib.mkIf cfg.enable {

  programs.zsh = {
    enable = true;
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
    enableAutosuggestions = true;
    enableCompletion = true;
    history = {
      path = "${config.xdg.stateHome}/zsh/zsh_history";
      extended = true;
      ignoreDups = true;
      expireDuplicatesFirst = true;
    };
    shellAliases = {
      cat = "bat -pp --theme=base16";
      reload = "exec ${config.programs.zsh.package}/bin/zsh";
      rebuild-home = "home-manager switch --flake ~/.config/nixos#${username}";
      rebuild-switch = "sudo nixos-rebuild switch --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-test = "sudo nixos-rebuild test --flake /home/${username}/.config/nixos#${hostname}";
      # cd here because I once had a bad experience where I accidentally built
      # in the nix store and it broke my entire install
      rebuild-build = "cd && nixos-rebuild build --flake /home/${username}/.config/nixos#${hostname}";
      rebuild-boot = "sudo nixos-rebuild boot --flake /home/${username}/.config/nixos#${hostname}";
      inspect-nix-config = "nix --extra-experimental-features repl-flake repl '/home/${username}/.config/nixos#nixosConfigurations.${hostname}'";
    };
    initExtra = /* bash */ ''
      setopt interactivecomments

      reboot() {
        read -q "REPLY?Are you sure you want to reboot? (y/n)"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          ${pkgs.systemd}/bin/reboot
        fi
      }

      edit-home-file() {
        if [ -z "$1" ] || [ ! -e "$1" ]; then
          echo "Usage: edit-home-file <file_path>"
          return 1
        fi

        local file_path="$1"
        local dir_path=$(dirname "$file_path")
        local file_name=$(basename -- "$file_path")

        local copy_path="$dir_path/''${file_name%.*}.copy.''${file_name##*.}"
        cat "$file_path" > "$copy_path" && rm "$file_path" && mv "$copy_path" "$file_path"
        $EDITOR "$file_path"
      }
    '';
  };

  impermanence = {
    directories = [
      ".config/zsh" # for zcompdump
      ".local/state/zsh"
      ".cache/zsh"
    ];
  };

}
